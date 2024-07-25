#!/bin/bash


# scRNA-seq需要下载cellranger程序
# https://www.10xgenomics.com/support/software/cell-ranger/downloads
# 下载解压后，将cellranger的路径添加到环境变量中，可以直接使用，不需要编译
# wget *** 
# tar -zxvf cellranger-8.0.1.tar.gz
# echo 'export PATH=/home/zhuhaoran/bio_software/cellranger-8.0.1:$PATH' >>~/.bashrc

# 可以顺便下载cellranger需要的基因组注释文件：
# wget "https://cf.10xgenomics.com/supp/cell-exp/refdata-gex-GRCh38-2024-A.tar.gz"



# 1. 第一步，下载scRNA_seq数据：
# 数据来源论文Single-cell transcriptomic analysis highlights origin and pathological process of human endometrioid endometrial carcinoma, Nature Communications
# 每个组只选择了一个样本
mkdir -p /home/zhuhaoran/2024.6.17/scRNA_seq_data
cd /home/zhuhaoran/2024.6.17/scRNA_seq_data || exit
### 开始下载, 逐行读取，逐个下载，得到的是.sra文件
mkdir -p raw_data
cd raw_data || exit
while read -r id; 
do 
prefetch "$id";   # 如果文件很大，增加文件大小限制参数，例如：prefetch --max-size 30G "$id"
done < ../SRAlist.txt   # prefetch是SRATOOLS中的一个命令，用于下载数据
# 比较耗时
# scRNA-seq文件非常大，一个sample是最小20g的数据。因此这里只下载了一个sample

# 将数据放到同一个文件夹
mkdir ../sc_raw
mv SRR*/*.sra ../sc_raw/
cd .. || exit  

# 2. 第二步，将.sra文件转换为fastq文件，使用SRATOOLS中的fastq-dump命令
# 逐个读取，逐个转换。
mkdir -p raw_fastq
for id in sc_raw/*.sra
do
    fastq-dump -O raw_fastq --gzip --split-files "$id";   # 非常慢
    # 较慢，得到fastq.gz文件。对于10X数据，会得到三个文件，分别代表index、<barcode或UMI>，reads。
done

# 以上为在公共数据库SRA中获得FASTQ数据的办法，实际情况中，公司测序会提供相应的FASTQ数据，而且是每个样本
# 一般三个（I1，R1，R2）或者两个（R1，R2）FASTQ文件，直接用于下一步的分析。
# 单个样本的10X单细胞测序数据分成I1，R1，R2三个测序文件。 R1文件每条序列包含26个碱基细胞识别条形码，10个碱基UMI。 
# I1文件包含8碱基的样本识别标签。 R2文件包含转录本测序信息。如果是多样本数据，则I1文件是必须的。
# scRNA-seq中，barcode用来标记一个细胞，而UMI用来标记单个转录本的分子。
# 如果想要每一步都独立处理，思路是首先进行序列比对，得到.bam文件后根据baecode和UMI信息将总的.bam文件分割成多个.bam文件，然后再进行表达量分析。
# 几乎所有的scRNA-seq分析都推荐使用cellRanger

# 3. 根据10X平台和cellranger的要求，10X平台需要对下载好的数据改名，改名规则为：SampleName_S1_L00X_R1_001.fastq.gz
# 例如：SRR1234567_S1_L001_R1_001.fastq.gz
# 观察3个数据大小，最小的是R1，最大的是R2
cd raw_fastq || exit
mv SRR17165230_1.fastq.gz SRR17165230_S1_L001_I1_001.fastq.gz
mv SRR17165230_2.fastq.gz SRR17165230_S1_L001_R1_001.fastq.gz
mv SRR17165230_3.fastq.gz SRR17165230_S1_L001_R2_001.fastq.gz

# 4. 第四步，使用fastqc和multiqc观察数据质量
# 因为仅仅是观察，没有实际质控，因此这一步省略，可以按需进行fastp质量控制

# 5. 第五步，使用cellranger进行数据处理
# cellranger要求你把一个sample的文件放到一个文件夹内，因此我们再处理一下
mkdir -p SRR17165230
mv SRR17165230* SRR17165230/

cd ..  # 回到scRNA_seq_data
cellranger count \
--id=SRR19842866 \
--transcriptome=/home/zhuhaoran/biological_data/refdata-gex-GRCh38-2024-A \
--fastqs=./raw_fastq/SRR17165230 \
--create-bam true
# cellranger count是cellranger的一个命令，用于处理生成count矩阵，可以直接接收fastq，省略了中间步骤   
# --id是输出文件夹的名字，--transcriptome是基因组注释文件夹，--fastqs是fastq文件夹
# 对于基因组的注释文件，这个大gz有10个g，其中包含了STAR（cellranger的序列比对使用了STAR）的index文件。每个序列比对算法的index文件都不一样，见bulk RNA-seq。
# 最重要的是整个基因组的文件，可从各大数据库下载。然后可以手动使用STAR建立索引，也可以使用cellranger的cellranger mkref命令建立索引。
# 当然下载已经处理好的文件最方便了
# wget "https://cf.10xgenomics.com/supp/cell-exp/refdata-gex-GRCh38-2024-A.tar.gz"

# 结束后，会有一个out文件夹，里面是输出结果。就可以使用Seurat进行下游分析了
