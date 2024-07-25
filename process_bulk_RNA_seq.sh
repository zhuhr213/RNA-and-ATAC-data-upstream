#!/bin/bash

# 1. 第一步，下载bulk_RNAseq数据：
mkdir -p /home/zhuhaoran/2024.6.17/bulk_RNA_seq_data
cd /home/zhuhaoran/2024.6.17/bulk_RNA_seq_data || exit
echo SRR13449223 > SRAlist.txt  # 保存SRR号, 以SRR13449223为例
### 开始下载, 逐行读取，逐个下载，得到的是.sra文件
mkdir -p raw_data
cd raw_data || exit
while read -r id; 
do 
prefetch "$id";   # 如果文件很大，增加文件大小限制参数，例如：prefetch --max-size 30G "$id"
done < ../SRAlist.txt   # prefetch是SRATOOLS中的一个命令，用于下载数据
# 比较耗时

# 2. 第二步，将.sra文件转换为fastq文件，使用SRATOOLS中的fastq-dump命令
cd ..
mkdir -p raw_srr_data
for file in raw_data/*
do  
    for data in "$file"/*.sra
    do
        mv "$data" raw_srr_data/
    done
done
rm -rf raw_data  # 将数据汇总到一个文件夹


# 逐个读取，逐个转换。
for id in raw_srr_data/*.sra
do
    fastq-dump -O raw_fastq --gzip --split-files "$id";   
    # 较慢，得到fastq.gz文件。对于SRR13449223数据，会生成两个文件：SRR13449223_1.fastq.gz和SRR13449223_2.fastq.gz
done  # 生成两个文件是因为做了双端测序，即从DNA的两端同时测序，相当于做了两次测序
# 6个文件非常慢

# 转换完成后，检查一下文件完整性，使用md5：
cd raw_fastq || exit
md5sum *.gz > md5sum.txt
md5sum -c md5sum.txt
### 如果出现以下内容，则没问题：
# SRR13449223_1.fastq.gz: OK
# SRR13449223_2.fastq.gz: OK


# 3. 第三步，查看数据质量，使用fastqc和multiqc
mkdir -p ../data_QC    # 此时在raw_fastq文件夹下
ls *gz | xargs fastqc -t 15 -o ../data_QC/    # 会在data_QC文件夹下生成4个文件，2个html和2个fastqc.zip文件，其中html文件可以用浏览器打开

# 使用multiqc合并fastqc的结果
cd ../data_QC/ || exit
multiqc . -o ../multiqc_report   # 这一步的作用只是为了查看数据质量，不是真正的数据质控
# 这个示例数据，有两项QC不通过，分别为：
# Per base sequence content：测序读段的某些碱基位置上，A、T、C、G四种碱基的比例显著不均衡，最直接的可能原因是接头影响，或重复序列，pcr过度扩增等
# Sequence Duplication Levels：测序数据中存在较高比例的重复序列，导致了潜在的冗余
# 但这两者对最终的结果影响不大，所以不需要过度处理


# 4. 第四步，真正的数据质控，使用fastp
# 一般情况下，在测序下机的时候，就已经对数据进行质控了，所以需要我们做的质控并不多，而且质控也不能过度，否则对
# 数据结果也是有影响的。
# 质控的主要功能：过滤掉冗余或不达标的数据：去除数据的接头，去除低质量数据，去除低质量碱基，去除低质量reads
cd ../raw_fastq || exit
mkdir -p ../clean_fastq
for file_name in ../raw_srr_data/*.sra
do
    name=${file_name##*/}
    var=${name%.sra}
    fastp -L -Q -f 12 -F 12 -D -i "$var"_1.fastq.gz -o ../clean_fastq/"$var"_1_clean.fastq.gz \
                               -I "$var"_2.fastq.gz -O ../clean_fastq/"$var"_2_clean.fastq.gz
done

# 数据质控完毕后，再次进行fastqc和multiqc，观察之前未通过的现在如何
mkdir -p ../clean_data_QC  # 此时在raw_fastq文件夹下
ls ../clean_fastq/*clean.fastq.gz | xargs fastqc -t 15 -o ../clean_data_QC/
# fastqc之后，发现sequence duplication levels依然未通过，可能的原因是pcr过度扩增、测序深度不足或样本本身问题，或接头污染

# 5. 第五步，序列比对，使用hisat2，是最重要的一步，注意需要提前下载对应物种的参考基因组index，并指定位置
cd .. || exit
mkdir -p hisat2_sam_data
for file_name in raw_srr_data/*.sra
do
    name=${file_name##*/}
    var=${name%.sra}
    hisat2 -t -p 10 -x ~/2024.6.17/human_index/hg38/genome \
    -1 ./clean_fastq/"$var"_1_clean.fastq.gz \
    -2 ./clean_fastq/"$var"_2_clean.fastq.gz \
    -S ./hisat2_sam_data/"$var".sam
done
# 生成的是sam文件，这一过程很慢，sam文件很大很大


# 6. 第六步，将sam文件转换为bam文件，使用samtools
mkdir -p bam_data
for file_name in hisat2_sam_data/*
do
    name=${file_name##*/}
    var=${name%.sam}
    samtools sort -O bam -@ 2 -o bam_data/"$var".bam "$file_name"
    samtools index bam_data/"$var".bam   # 建立索引，查找会更快
    # samtools view bam_data/"$var".bam | less -SN #查看bam文件具体是啥东西
    samtools flagstat -@ 2 bam_data/"$var".bam #查看比对结果
done


# 7. 第七步，生成count matrix，使用featureCounts
# conda install subread

### 在进行count matrix之前，需要准备好基因组的注释文件，注释文件通常为gff、gtf格式。里面详细记录了
### 基因的名称、位置，exon的位置等信息。
### 由于我们已经进行过了序列比对，也就知道了每个reads的位置，所以可以根据这个位置信息，来统计每个基因的reads数

# 这里使用的是来自gencode的gtf文件，给出下载链接：
# http://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_46/，选择gencode.v46.annotation.gtf.gz

# 下载后请注意解压

# 注释文件各大数据库（NCBI，UCSC，GENCODE，ENSEMBLE）都有提供，需要注意，每一家都不一样。
# https://hgdownload.soe.ucsc.edu/goldenPath/hg38/bigZips/genes/；
# https://ftp.ensembl.org/pub/release-112/gtf/homo_sapiens/
# https://ftp.ncbi.nlm.nih.gov/refseq/H_sapiens/annotation/annotation_releases/GCF_009914755.1-RS_2023_10/GCF_009914755.1_T2T-CHM13v2.0_genomic.gtf.gz

# featureCounts --help
mkdir -p feature_counts
for file_name in bam_data/*.bam  # 遍历所有.bam文件
do
    name=${file_name##*/}
    var=${name%.bam}  # 获取文件前缀
    featureCounts  -T 5 -p -t exon -g gene_name \
                -a ~/biological_data/hg38/gencode.v46.annotation.gtf \
                -o ./feature_counts/"$var"_fea.count \
                "$file_name"
done
# -t 指定 feature type，有gene、transcript、exon等。exon是外显子，被真正表达出来的部分，所以选exon
# -g 指定 gtf文件中的注释attribute type，我们选择gene_name，还有transcript_name、gene_id之类的东西
# 也可以选择gene_id，随后再转化为gene_name
# -a 指定注释文件
# -o 指定输出，所有参数指定后，最后一个直接输入源文件
# -T 线程数

# 8. 接下来，就可以使用R语言进行下游分析了！Bulk数据分析本次实验使用DESeq2，这个包用来分析样本间的基因表达差异
# 由于是服务器环境，我因此新建了一个专门的R环境。
# r-base version = 4.3.3
# conda create -n R
# conda install r-base=4.3.3 -c conda-forge
# conda install r-ggplot2 r-Matrix r-biocmanager r-xml2
# 缺什么安什么

# R环境内
# BiocManager::install("DESeq2")
# conda activate R 
Rscript data_analyse.R  # 运行分析程序