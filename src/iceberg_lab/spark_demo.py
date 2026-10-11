"""Create, write and query an Iceberg table with a local Spark session."""

import os

import pyspark
from pyspark.sql import SparkSession

ICEBERG_VERSION = os.environ.get("ICEBERG_VERSION", "1.10.0")
# The Iceberg runtime jar must match the installed Spark minor version; Spark 4 only ships Scala 2.13
SPARK_MINOR_VERSION = ".".join(pyspark.__version__.split(".")[:2])
POLARIS_URI = os.environ.get("POLARIS_URI", "http://localhost:8181/api/catalog")
POLARIS_CREDENTIAL = os.environ.get("POLARIS_CREDENTIAL", "root:s3cr3t")
S3_ENDPOINT = os.environ.get("S3_ENDPOINT", "http://localhost:9000")


def get_spark() -> SparkSession:
    catalog = "spark.sql.catalog.polaris"
    return (
        SparkSession.builder.master("local[*]")
        .appName("iceberg-lab")
        .config(
            "spark.jars.packages",
            f"org.apache.iceberg:iceberg-spark-runtime-{SPARK_MINOR_VERSION}_2.13:{ICEBERG_VERSION},"
            f"org.apache.iceberg:iceberg-aws-bundle:{ICEBERG_VERSION}",
        )
        .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions")
        .config("spark.sql.defaultCatalog", "polaris")
        .config(catalog, "org.apache.iceberg.spark.SparkCatalog")
        .config(f"{catalog}.type", "rest")
        .config(f"{catalog}.uri", POLARIS_URI)
        .config(f"{catalog}.warehouse", "quickstart_catalog")
        .config(f"{catalog}.rest.auth.type", "oauth2")
        .config(f"{catalog}.oauth2-server-uri", f"{POLARIS_URI}/v1/oauth/tokens")
        .config(f"{catalog}.credential", POLARIS_CREDENTIAL)
        .config(f"{catalog}.scope", "PRINCIPAL_ROLE:ALL")
        .config(f"{catalog}.token-refresh-enabled", "true")
        .config(f"{catalog}.io-impl", "org.apache.iceberg.aws.s3.S3FileIO")
        .config(f"{catalog}.s3.endpoint", S3_ENDPOINT)
        .config(f"{catalog}.s3.path-style-access", "true")
        .config(f"{catalog}.s3.access-key-id", "admin")
        .config(f"{catalog}.s3.secret-access-key", "password")
        .config(f"{catalog}.client.region", "us-west-2")
        .getOrCreate()
    )


def main() -> None:
    spark = get_spark()

    spark.sql("CREATE NAMESPACE IF NOT EXISTS demo")
    spark.sql(
        """
        CREATE TABLE IF NOT EXISTS demo.events (
            id BIGINT,
            kind STRING,
            ts TIMESTAMP
        )
        USING iceberg
        PARTITIONED BY (days(ts))
        """
    )

    spark.sql(
        """
        INSERT INTO demo.events VALUES
            (1, 'click', TIMESTAMP '2026-10-01 10:00:00'),
            (2, 'view',  TIMESTAMP '2026-10-01 11:30:00'),
            (3, 'click', TIMESTAMP '2026-10-02 09:15:00')
        """
    )

    spark.sql("SELECT kind, count(*) AS n FROM demo.events GROUP BY kind ORDER BY kind").show()
    spark.sql("SELECT snapshot_id, operation, committed_at FROM demo.events.snapshots").show(truncate=False)

    spark.stop()


if __name__ == "__main__":
    main()
