# Based on https://github.com/tamslo/uyg-docker

FROM ubuntu:25.04

ENV INSTALLATION_DIRECTORY=/opt
RUN apt-get update

# Install plink (see https://www.cog-genomics.org/plink/1.9/)

RUN apt-get install -y unzip
RUN apt-get install -y wget

WORKDIR $INSTALLATION_DIRECTORY/plink
ENV PLINK_URL=https://s3.amazonaws.com/plink1-assets
ENV PLINK_FILE=plink_linux_x86_64_20241022.zip
RUN wget ${PLINK_URL}/${PLINK_FILE}
RUN unzip ${PLINK_FILE}
RUN rm ${PLINK_FILE}
ENV PATH="$PATH:$INSTALLATION_DIRECTORY/plink"

# Install BCFtools (see https://samtools.github.io/bcftools/howtos/install.html)
# and Samtools (see https://github.com/samtools/samtools/blob/develop/INSTALL)

RUN apt-get install -y git
RUN apt-get install -y make
RUN apt-get install -y gcc
RUN apt-get install -y zlib1g-dev
RUN apt-get install -y libgsl-dev
RUN apt-get install -y liblzma-dev
RUN apt-get install -y libbz2-dev
RUN apt-get install -y perl
RUN apt-get install -y libcurl4-openssl-dev
RUN apt-get install -y autoconf

WORKDIR $INSTALLATION_DIRECTORY
RUN git clone --recurse-submodules https://github.com/samtools/htslib.git
RUN git clone https://github.com/samtools/bcftools.git
WORKDIR $INSTALLATION_DIRECTORY/bcftools
RUN autoheader
RUN autoconf
RUN ./configure --enable-libgsl
RUN make
ENV PATH="$PATH:$INSTALLATION_DIRECTORY/bcftools"
ENV BCFTOOLS_PLUGINS=${INSTALLATION_DIRECTORY}/bcftools/plugins

RUN apt-get install -y libncurses-dev

WORKDIR $INSTALLATION_DIRECTORY
RUN git clone https://github.com/samtools/samtools.git
WORKDIR $INSTALLATION_DIRECTORY/samtools
RUN autoheader
RUN autoconf
RUN ./configure
RUN make
RUN make install

# Install Beagle (for imputation)

WORKDIR $INSTALLATION_DIRECTORY
RUN apt-get install -y openjdk-17-jdk
ENV BEAGLE_VERSION=27Feb25.75f
RUN wget https://faculty.washington.edu/browning/beagle/beagle.${BEAGLE_VERSION}.jar
RUN mv beagle.${BEAGLE_VERSION}.jar beagle.jar

# Install further helper tools

# Includes bgzip
RUN apt-get install -y tabix

WORKDIR ${INSTALLATION_DIRECTORY}
