# Use a base image with bash and sqlcmd installed
FROM mcr.microsoft.com/mssql-tools

# Install column command
RUN apt-get update && apt-get install -y bsdmainutils

# Set the working directory
WORKDIR /app

# Set environment variables if not using settings.conf
ENV SERVER_IP=${SERVER_IP:-"default_server_ip"}
ENV SA_USER=${SA_USER:-"default_sa_user"}
ENV SA_PASSWORD=${SA_PASSWORD:-"default_sa_password"}

# Make sqlcmd executable available in the PATH
ENV PATH="$PATH:/opt/mssql-tools/bin"

# Copy the script into the container
COPY fix-orphaned-users.sh /app/fix-orphaned-users.sh

# Make the script executable
RUN chmod +x /app/fix-orphaned-users.sh

# Set the entrypoint to the script
ENTRYPOINT ["/app/fix-orphaned-users.sh"]
