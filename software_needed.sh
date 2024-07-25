#!/bin/bash
### RNA-seq and ATAC-seq data

### python version=3.9.7
### os version=ubuntu 18.04，8号服务器

# 下载安装下载数据需要的软件：SARTOOLS，FASTQC等
### SARTOOLS，用来下载初始数据
mkdir -p ~/bio_software
cd ~/bio_software || exit
wget https://ftp-trace.ncbi.nlm.nih.gov/sra/sdk/3.1.1/sratoolkit.3.1.1-ubuntu64.tar.gz  # 建议使用ubuntu系统，如果你使用的是mac或windows，请前往https://ftp-trace.ncbi.nlm.nih.gov/sra/sdk/3.1.1/
tar -zxvf sratoolkit.3.1.1-ubuntu64.tar.gz  # 解压
export PATH="$PATH:~/bio_software/sratoolkit.3.1.1-ubuntu64/bin" >> ~/.bashrc  # 不需编译安装，直接添加环境变量
# source ~/.bashrc  # 更新环境变量

### FASTQC，评估数据质量，没有质控的功能，就是单纯的查看
cd ~/bio_software || exit
wget https://www.bioinformatics.babraham.ac.uk/projects/fastqc/fastqc_v0.12.1.zip
unzip fastqc_v0.12.1.zip
cd FastQC || exit
chmod +x fastqc
export PATH="$PATH:~/bio_software/FastQC" >> ~/.bashrc   # 不需编译安装，添加环境变量
source ~/.bashrc  # 更新环境变量

### multiqc，用于合并多个fastqc的结果，请注意激活环境
pip install multiqc

### fastp：数据质控(过滤低质量），一般数据在测序时就已经做好了质控，所以最好不要过度质控，注意首先激活环境
conda install -c bioconda fastp


### hisat2，用于序列比对
cd ~/bio_software || exit
wget https://cloud.biohpc.swmed.edu/index.php/s/oTtGWbWjaxsQ2Ho/download
unzip download  # 下载的文件就叫download
rm download
echo "export PATH=~/bio_software/hisat2-2.2.1:$PATH" >> ~/.bashrc  # 不需编译安装，直接添加环境变量
source ~/.bashrc
hisat2 --help  # 测试是否安装成功

# 序列比对需要下载对应物种的参考基因组index，以人类为例，可以在hisat2官网下载到：http://daehwankimlab.github.io/hisat2/download/
# 这里是基因组的index，可以根据需要选择下载转录组的index
cd ~/bio_software || exit
mkdir human_index
cd human_index || exit
wget https://genome-idx.s3.amazonaws.com/hisat/hg38_genome.tar.gz
tar -xvzf hg38_genome.tar.gz

# 包含的make_hg38.sh提供构建索引的过程，这一过程的思路是，根据基因组的fasta文件（很大），主动地去建立索引，
# 使得在序列比对时能够快速找到对应的位置，而不是遍历整个基因组
# 每一个序列比对软件的index建立方法都不一样，例如这里的是生成ht2文件
# 整个基因组文件可以从UCSC，ensemble等数据库下载：https://hgdownload.soe.ucsc.edu/goldenPath/hg38/bigZips/

### samtools，用于处理比对后的sam文件，将其转化为不怎么占存储的二进制格式.bam
# 由于服务器系统版本较低，必要的编程库版本低，建议使用conda安装，python环境3.9.7，server8上为samtools=1.13
conda install -c bioconda samtools
# 如果您使用的是自己的ubuntu或macos，则建议您从https://github.com/samtools/samtools/releases/download/1.20/samtools-1.20.tar.bz2下载源码，然后编译安装


### 定量工具：featureCounts，用于定量基因表达
# featureCounts是subread的一个小工具，所以安装subread就可以使用他了
conda install -c bioconda subread


# scRNA-seq需要下载cellranger程序
# https://www.10xgenomics.com/support/software/cell-ranger/downloads
# 下载解压后，将cellranger的路径添加到环境变量中，可以直接使用，不需要编译
# wget *** 
# tar -zxvf cellranger-8.0.1.tar.gz
# echo 'export PATH=/home/zhuhaoran/bio_software/cellranger-8.0.1:$PATH' >>~/.bashrc


# scATAC-seq处理软件为cellranger-atac
# https://support.10xgenomics.com/single-cell-atac/software/downloads/latest?
# 与cellranger安装步骤相同