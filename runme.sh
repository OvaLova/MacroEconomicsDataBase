#!/bin/bash

# Unzip the datasets
echo
echo
echo "################### Unzipping DataSets.zip ###################"
echo
unzip DataSets.zip

# Create the database and apply the schema
echo
echo
echo "################### Creating and populating the SQLite database ###################"
sqlite3 project.db << EOF
.read schema.sql
.quit
EOF

# Remove the unzipped DataSets directory
echo
echo
echo "################### Cleaning up the extracted files ###################"
rm -r -f DataSets

# Run the queries
echo
echo
echo "################### Running queries ###################"
sqlite3 project.db << EOF
.read queries.sql
.quit
EOF
