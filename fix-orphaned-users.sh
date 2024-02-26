#!/bin/bash

# This script assists in resolving orphaned users in a SQL Server database.
# An orphaned user occurs when a user in a database does not have a corresponding login on the instance.
# The script provides a menu-driven interface to manage database roles and schema ownerships,
# which is necessary to drop orphaned users who own schemas or roles within the database.
# The script assists to transfer ownership of roles and schemas to 'dbo', check role ownership,
# and eventually drop the orphaned user from the database.
#
# The script is inspired by the article at
# https://www.mssqltips.com/sqlservertip/2620/steps-to-drop-an-orphan-sql-server-user-when-it-owns-a-schema-or-role/
# For more information about orphaned users, refer to the Microsoft Azure article:
# https://learn.microsoft.com/en-us/sql/sql-server/failover-clusters/troubleshoot-orphaned-users-sql-server?view=sql-server-ver16
#
# Usage:
# 1. Source the script with necessary SQL Server connection settings in 'settings.conf'.
# 2. Run the script and follow the prompts to select the target user and database.
# 3. Choose the appropriate action from the menu to manage roles and schemas or drop the user.
# 4. Repeat the process or exit the script as needed.

# Check if settings.conf exists and source it, otherwise use environment variables
if [ -f settings.conf ]; then
    source settings.conf
else
    SERVER_IP=${SERVER_IP:-"default_server_ip"}
    SA_USER=${SA_USER:-"default_sa_user"}
    SA_PASSWORD=${SA_PASSWORD:-"default_sa_password"}
fi

# Define the path to $SQLCMD
SQLCMD=${SQLCMD:-"$(which sqlcmd)"}

while true; do
    # Prompt user for the target user and database
    read -p "Enter the target user: " TARGET_USER
    read -p "Enter the target database: " DATABASE

    # Menu loop
    while true; do
        # Display menu with a single-line border
        echo "┌──────────────────────────────────────────────────────────────────────────────┐"
        echo "│ Select the query to run:                                                     │"
        echo "├──────────────────────────────────────────────────────────────────────────────┤"
        echo "│ 1. Get Database Roles owned by target User                                   │"
        echo "│ 2. Get Database Schemas owned by target User                                 │"
        echo "│ 3. Check ownership of db_owner role (should be owned by dbo user)            │"
        echo "│ 4. Transfer ownership of db_owner role to dbo                                │"
        echo "│ 5. Transfer ownership of schemas to dbo (so the target User can be dropped)  │"
        echo "│ 6. Transfer ownership of schemas back to the target User                     │"
        echo "│ 7. Drop the target User from the target Database                             │"
        echo "│ 8. Start over                                                                │"
        echo "│ 9. Quit                                                                      │"
        echo "└──────────────────────────────────────────────────────────────────────────────┘"
        read -p "Enter your choice (1-9): " QUERY_CHOICE

        # Connect to the SQL Server and select the database
        $SQLCMD -S $SERVER_IP -U $SA_USER -P $SA_PASSWORD -d $DATABASE -Q "SET NOCOUNT ON;"

        case "$QUERY_CHOICE" in
            1)
                # Query to Get Database Roles Owned by a User
                $SQLCMD -S $SERVER_IP -U $SA_USER -P $SA_PASSWORD -d $DATABASE -W -s "|" -Q "
                SELECT
                    dp2.name AS RoleName,
                    dp1.name AS OwnerName
                FROM
                    sys.database_principals AS dp1
                INNER JOIN
                    sys.database_principals AS dp2
                    ON dp1.principal_id = dp2.owning_principal_id
                WHERE
                    dp1.name = '$TARGET_USER';
                " | column -t -s '|'
                ;;
            2)
                # Query to Get Database Schemas Owned by a User
                $SQLCMD -S $SERVER_IP -U $SA_USER -P $SA_PASSWORD -d $DATABASE -W -s "|" -Q "
                SELECT
                    SCHEMA_NAME AS SchemaName,
                    SCHEMA_OWNER AS OwnerName
                FROM
                    INFORMATION_SCHEMA.SCHEMATA
                WHERE
                    SCHEMA_OWNER = '$TARGET_USER';
                " | column -t -s '|'
                ;;
            3)
                # Query to Check ownership of db_owner role
                $SQLCMD -S $SERVER_IP -U $SA_USER -P $SA_PASSWORD -d $DATABASE -W -s "|" -Q "
                SELECT
                    dp.name AS RoleName,
                    dp2.name AS OwnerName
                FROM
                    sys.database_role_members drm
                JOIN
                    sys.database_principals dp ON drm.role_principal_id = dp.principal_id
                JOIN
                    sys.database_principals dp2 ON dp.owning_principal_id = dp2.principal_id
                WHERE
                    dp.name = 'db_owner';
                " | column -t -s '|'
                ;;
            4)
                # Query to Transfer ownership of the "db_owner" role to "dbo"
                $SQLCMD -S $SERVER_IP -U $SA_USER -P $SA_PASSWORD -d $DATABASE -Q "
                ALTER AUTHORIZATION ON ROLE::db_owner TO dbo;
                "
                ;;
            5)
                # Query to Transfer ownership of schemas to "dbo"
                read -p "Enter the schema names to transfer ownership, separated by commas: " SCHEMA_NAMES
                IFS=',' read -ra SCHEMA_ARRAY <<< "$SCHEMA_NAMES"
                for SCHEMA_NAME in "${SCHEMA_ARRAY[@]}"; do
                    $SQLCMD -S $SERVER_IP -U $SA_USER -P $SA_PASSWORD -d $DATABASE -Q "
                    ALTER AUTHORIZATION ON SCHEMA::[${SCHEMA_NAME// /}] TO dbo;
                    "
                done
                ;;
            6)
                # Query to Alter authorization of the selected schema names
                read -p "Enter the schema names, separated by commas: " SCHEMA_NAMES
                IFS=',' read -ra SCHEMA_ARRAY <<< "$SCHEMA_NAMES"
                for SCHEMA_NAME in "${SCHEMA_ARRAY[@]}"; do
                    $SQLCMD -S $SERVER_IP -U $SA_USER -P $SA_PASSWORD -d $DATABASE -Q "
                    ALTER AUTHORIZATION ON SCHEMA::[${SCHEMA_NAME// /}] TO [$TARGET_USER];
                    "
                done
                ;;
            7)
                # Query to Drop the target user from the target database
                $SQLCMD -S $SERVER_IP -U $SA_USER -P $SA_PASSWORD -d $DATABASE -Q "
                DROP USER [$TARGET_USER];
                "
                ;;
            8)
                # Break out of the inner loop to start over
                break
                ;;
            9)
                echo "Exiting script."
                exit 0
                ;;
            *)
                echo "Invalid choice. Please select a number between 1 and 9."
                ;;
        esac
        # Return to the main menu
    done
done
