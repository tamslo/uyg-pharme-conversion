# Based on https://github.com/tamslo/uyg-docker

FROM ubuntu:25.04

ENV INSTALLATION_DIRECTORY=/opt
RUN apt-get update

# Install plink (see https://www.cog-genomics.org/plink/1.9/)

RUN apt-get install -y wget unzip
ENV PLINK_URL=https://s3.amazonaws.com/plink1-assets
ENV PLINK_FILE=plink_linux_x86_64_20241022.zip
RUN wget ${PLINK_URL}/${PLINK_FILE}
RUN unzip ${PLINK_FILE} -d $INSTALLATION_DIRECTORY
RUN rm ${PLINK_FILE}
ENV PATH="$PATH:$INSTALLATION_DIRECTORY"
