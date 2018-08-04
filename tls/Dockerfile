FROM nginx
LABEL maintainer="PolySwarm Developers <info@polyswarm.io>"

WORKDIR /usr/src/app
COPY . .

# Set up certs
COPY test_ca/ /ca
COPY nginx.conf /etc/nginx/polyswarm.conf

# New run script overrides polyswarmd command

CMD nginx -c /etc/nginx/polyswarm.conf