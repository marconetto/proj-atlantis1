FROM ubuntu:latest

# Install required packages
RUN apt-get update && apt-get install -y \
    tzdata

# Copy the script to the container
COPY myapploop.sh /usr/local/bin/myapploop.sh
COPY myapp.sh /usr/local/bin/myapp.sh

# Make the script executable
RUN chmod +x /usr/local/bin/myapp.sh
RUN chmod +x /usr/local/bin/myapploop.sh

# Set the script as the entrypoint
# ENTRYPOINT ["/usr/local/bin/myapp.sh"]
ENTRYPOINT ["/usr/local/bin/myapploop.sh"]

