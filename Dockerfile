FROM alpine 

RUN apk --update add curl
RUN apk --update add jq

COPY ./enode.sh ./enode.sh

RUN chmod 755 ./enode.sh

CMD \\\"./enode.sh\\\"
