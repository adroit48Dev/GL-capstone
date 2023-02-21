FROM ubuntu:20.04

RUN apt-get update
RUN apt-get -y install software-properties-common
RUN add-apt-repository -y ppa:ethereum/ethereum
RUN apt-get -y install ethereum
RUN apt-get -y upgrade geth
RUN apt-get -y install curl

COPY . /app

RUN geth --datadir /app/data init /app/genesis.json
    
RUN chmod +x /app/docker/startup.sh

CMD sh /app/docker/startup.sh
