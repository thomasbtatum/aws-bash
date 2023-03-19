#!/bin/bash

# Set variables
cluster_name="apg-138"
cluster_instance_name="${cluster_name}-writer"
reader_instance_name="${cluster_name}-reader"
subnet_group="your-db-subnet-group"
security_group="your-db-security-group"
log_file="aws_rds_creation.log"
progress_interval=15

# Create RDS Aurora PostgreSQL cluster
echo "Creating RDS Aurora PostgreSQL cluster '${cluster_name}'..."
aws rds create-db-cluster \
    --db-cluster-identifier "${cluster_name}" \
    --engine aurora-postgresql \
    --engine-version 13.8 \
    --master-username your_master_username \
    --master-user-password your_master_password \
    --region us-east-1 | tee -a "cluster-${log_file}"

# Wait for the cluster to be available
echo "Waiting for the cluster '${cluster_name}' to be available..."
while true; do
    cluster_status=$(aws rds describe-db-clusters --db-cluster-identifier "${cluster_name}" --query "DBClusters[0].Status" --output text)
    if [ "${cluster_status}" == "available" ]; then
        echo "Cluster '${cluster_name}' is available."
        break
    else
        echo "Cluster '${cluster_name}' status: ${cluster_status}"
        sleep ${progress_interval}
    fi
done

# Create writer instance
echo "Creating writer instance '${cluster_instance_name}'..."
aws rds create-db-instance \
    --db-instance-identifier "${cluster_instance_name}" \
    --db-cluster-identifier "${cluster_name}" \
    --engine aurora-postgresql \
    --db-instance-class db.t3.large --region us-east-1 | tee -a "writer-${log_file}"

# Create reader instance
echo "Creating reader instance '${reader_instance_name}'..."
aws rds create-db-instance \
    --db-instance-identifier "${reader_instance_name}" \
    --db-cluster-identifier "${cluster_name}" \
    --engine aurora-postgresql \
    --db-instance-class db.t3.large --region us-east-1 \
    --tags Key=Role,Value=Reader | tee -a "reader-${log_file}"

# Wait for instances to be available
instance_list="${cluster_instance_name},${reader_instance_name}"
echo "Waiting for instances '${instance_list}' to be available..."
for instance in $(echo ${instance_list} | sed "s/,/ /g"); do
    while true; do
        instance_status=$(aws rds describe-db-instances --db-instance-identifier "${instance}" --query "DBInstances[0].DBInstanceStatus" --output text)
        if [ "${instance_status}" == "available" ]; then
            echo "Instance '${instance}' is available."
            break
        else
            echo "Instance '${instance}' status: ${instance_status}"
            sleep ${progress_interval}
        fi
    done
done

# Print return code
return_code=$?
echo "Script execution complete with return code: ${return_code}"
exit ${return_code}
