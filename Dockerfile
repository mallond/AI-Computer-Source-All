# ---- Build stage: compile Rust binary ----------------------------------------
#  RUN ls -al && sleep 5
FROM rust:1.81-bookworm AS builder

COPY . ./

# Install the compiled binary into /out/bin/<your-binary-name>
RUN echo 'magic'
# Debug what files are present
RUN ls -al && sleep 1

RUN ./start.sh

RUN mv ./cgi/target/release/cgi /www/cgi

RUN apt-get update \
 && apt-get install -y --no-install-recommends lighttpd bash ca-certificates

RUN  mv ./www/* /var/www
EXPOSE 8090
CMD ["lighttpd","-D","-f","./lighttpd.conf"]
