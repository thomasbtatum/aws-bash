#!/bin/bash

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <source_version> <target_version> <region>"
    exit 1
fi

source_version=$1
target_version=$2
cluster_region=$3
cluster_name="apg138-source-cluster"
log_file="apg138-source-cluster.log"
username="dbuser"
password="dbpassword"

echo "Creating AWS RDS Aurora PostgreSQL cluster..."
aws rds create-db-cluster --region $cluster_region \
    --db-cluster-identifier $cluster_name \
    --engine aurora-postgresql \
    --engine-version $source_version \
    --master-username $username \
    --master-user-password $password  >> cluster-$log_file

echo "Creating Writer instance..."
aws rds create-db-instance \
    --db-instance-identifier "${cluster_name}-writer" \
    --db-cluster-identifier $cluster_name \
    --engine aurora-postgresql \
    --db-instance-class db.t3.large >> writer-$log_file

echo "Creating Reader instance..."
aws rds create-db-instance  \
    --db-instance-identifier "${cluster_name}-reader" \
    --db-cluster-identifier $cluster_name \
    --engine aurora-postgresql \
    --db-instance-class db.t3.large \
    --no-multi-az >> reader-$log_file

wait_for_cluster_available() {
    local cluster_status
    while true; do
        cluster_status=$(aws rds describe-db-clusters --db-cluster-identifier $cluster_name --query "DBClusters[0].Status" --output text)
        if [ "$cluster_status" = "available" ]; then
            break
        fi
        echo -n "."
        sleep 10
    done
}

echo -n "Waiting for the cluster to become available"
wait_for_cluster_available
echo
echo "Cluster is now available"

echo "Waiting for 5 minutes before migrating to target version..."
sleep 300

echo "Migrating the cluster to Aurora PostgreSQL target version $target_version"
aws rds modify-db-cluster \
    --db-cluster-identifier $cluster_name \
    --engine-version $target_version \
    --apply-immediately >> migrate-$log_file

echo -n "Waiting for the migration to complete and the cluster to become available"
wait_for_cluster_available
echo
echo "Migration to target version $target_version is complete, and the cluster is now available"
