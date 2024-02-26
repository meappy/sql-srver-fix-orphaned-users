# Use a base image with bash and sqlcmd installed
FROM mcr.microsoft.com/mssql-tools

# Set the working directory
WORKDIR /app

# Copy the script into the container
COPY fix-orphaned-users.sh /app/fix-orphaned-users.sh

# Make the script executable
RUN chmod +x /app/fix-orphaned-users.sh

# Set the entrypoint to the script
ENTRYPOINT ["/app/fix-orphaned-users.sh"]
