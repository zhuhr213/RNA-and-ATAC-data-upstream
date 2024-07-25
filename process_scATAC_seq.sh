#!/bin/bash
# scATAC的数据实在是太大了
# 1. 下载数据
# 2. 将数据转换为fastq
# 3. 使用cellranger-atac进行分析

# 一个可用的数据：https://www.ncbi.nlm.nih.gov/Traces/study/?acc=PRJNA532774&o=acc_s%3Aa
# 来自论文：Massively parallel single-cell chromatin landscapes of human immune cell development and intratumoral T cell exhaustion， NBT，2019
# 所有样本源数据加一起一共400+GB
# 如果只使用下面的这个样本，下载数据的同时还会下载109个依赖文件




# 这里使用一个10X平台的数据，只有40g
# Input Files
wget https://s3-us-west-2.amazonaws.com/10x.files/samples/cell-atac/2.1.0/10k_pbmc_ATACv2_nextgem_Chromium_Controller/10k_pbmc_ATACv2_nextgem_Chromium_Controller_fastqs.tar
# 下载好后解压

# 如果你是从SRR下载的数据，需要把他们处理为fastq。
# fastq-dump -O ./raw_fastq --gzip --split-files ./SRR8893744/SRR8893744.sra
# 一般情况下，10X的sc-ATAC的FASTQ文件有4个，一个I1，剩下的分别是R1、R2、R3。
# 但是有些时候只有三个，并没有I1，不过后面的三个文件完整也是可以跑流程的。
# R1，R2，R3，I1分别代表read 1，barcode，read 2 和 sample index

#接着修改文件名（mv命令）
# mv ./raw_fastq/SRR8893771_1.fastq.gz ./raw_fastq/SRR8893771_S1_L001_I1_001.fastq.gz
# mv ./raw_fastq/SRR8893771_2.fastq.gz ./raw_fastq/SRR8893771_S1_L001_R1_001.fastq.gz
# mv ./raw_fastq/SRR8893771_3.fastq.gz ./raw_fastq/SRR8893771_S1_L001_R2_001.fastq.gz
# mv ./raw_fastq/SRR8893771_4.fastq.gz ./raw_fastq/SRR8893771_S1_L001_R3_001.fastq.gz


# 使用scATAC-seq的基因组注释文件，和scRNA的不一样
# wget https://cf.10xgenomics.com/supp/cell-atac/refdata-cellranger-arc-GRCh38-2020-A-2.0.0.tar.gz
# tar -zxvf refdata-cellranger-arc-GRCh38-2020-A-2.0.0.tar.gz

nohup \
cellranger-atac count \
 --id=out_pbmc \
 --reference=/home/zhuhaoran/biological_data/refdata-cellranger-arc-GRCh38-2020-A-2.0.0 \
 --fastqs=./raw_fastq/10k_pbmc_ATACv2_nextgem_Chromium_Controller_fastqs \
 > cellranger-atac.out 2>&1 &
# 与scRNA-seq流程相同

# scATAC数据是三种测序技术中占用内存和硬盘最大的


# 处理好后，可以使用ArchR进行进一步的下游分析

# https://support.10xgenomics.com/single-cell-atac/software/downloads/latest?
# singlecell.csv: 每个细胞的信息，如是否在TSS
# possorted_bam.bam,possorted_bam.bam.bai: 处理后的BAM与其索引
# raw_peak_bc_matrix.h5: 原始的peak-cell矩阵, h5格式存放
# raw_peak_bc_matrix: 原始的peak-cell矩阵
# analysis: 各种分析结果，如聚类，富集，降维等
# filtered_peak_bc_matrix.h5: 过滤后的peak-cell矩阵, h5格式存放
# filtered_peak_bc_matrix: 过滤后的peak-cell矩阵
# fragments.tsv.gz, fragments.tsv.gz.tbi: 每个barcode的序列和它对应的基因组位置和数目
# filtered_tf_bc_matrix.h5: 过滤后的TF-cell矩阵, h5格式存放
# filtered_tf_bc_matrix: 过滤后的TF-cell矩阵
# cloupe.cloupe: Loupe Cell Browser的输入文件
# summary.csv, summary.json: 数据的统计结果, 以csv和json格式存放
# web_summary.html: 网页总结信息
# peaks.bed: 所有的peak汇总
# peak_annotation.csv: peak的注释结果


