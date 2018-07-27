FROM python:3.5
LABEL maintainer="PolySwarm Developers <info@polyswarm.io>"

RUN pip install websockets
RUN pip install web3

COPY ./scripts ./scripts

CMD ["python ./scripts/listen_to_arbiter_events.py"]

