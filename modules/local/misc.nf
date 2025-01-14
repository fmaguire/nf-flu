include { getSoftwareName; fluPrefix } from './functions'

process CAT_NANOPORE_FASTQ {
  tag "${meta.id}"
  label 'process_low'

  conda (params.enable_conda ? "conda-forge::pigz=2.6" : null)
  if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
      container "https://depot.galaxyproject.org/singularity/mulled-v2-2b04072095278721dc9a5772e61e406f399b6030:7c7abf911e92d7fb831611ffb965f3cf7fe2c01d-0"
  } else {
      container "quay.io/biocontainers/mulled-v2-2b04072095278721dc9a5772e61e406f399b6030:7c7abf911e92d7fb831611ffb965f3cf7fe2c01d-0"
  }

  input:
  tuple val(meta), path(fqgz), path(fq)

  output:
  tuple val(meta), path(merged_fqgz), emit: reads
  path "versions.yml" , emit: versions

  script:
  merged_fqgz = "${meta.id}.merged.fastq.gz"
  def fqList = fq.collect { it.toString() }
  def fqgzList = fqgz.collect { it.toString() }
  """
  touch $merged_fqgz
  if [ ${fqList.size} -gt 0 ]; then
    cat $fq | pigz -ck >> $merged_fqgz
  fi
  if [ ${fqgzList.size} -gt 0 ]; then
    cat $fqgz >> $merged_fqgz
  fi
  cat <<-END_VERSIONS > versions.yml
  "${task.process}":
      pigz: \$(pigz --version 2>&1 | sed 's/pigz //g' )
  END_VERSIONS
  """
}

process CAT_DB {
    tag "$fasta1 - $fasta2"

    executor 'local'
    memory 100.MB

    input:
    path(fasta1)
    path(fasta2)

    output:
    path("influenza_db.fasta"), emit: fasta

    script:
    """
    cp $fasta1 influenza_db.fasta
    echo >> influenza_db.fasta
    cat $fasta2 >> influenza_db.fasta
    """
}

process GUNZIP_NCBI_FLU_FASTA {
    tag "$archive"
    label 'process_low'

    conda (params.enable_conda ? "conda-forge::sed=4.7" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://containers.biocontainers.pro/s3/SingImgsRepo/biocontainers/v1.2.0_cv1/biocontainers_v1.2.0_cv1.img"
    } else {
        container "biocontainers/biocontainers:v1.2.0_cv1"
    }

    input:
    path archive

    output:
    path "*.fna", emit: fna
    path "versions.yml" , emit: versions

    script:
    def software = getSoftwareName(task.process)
    // replace FASTA headers
    // >gi|{gi}|gb|{accession}|{description}
    // with
    // >{accession} {description}
    // for easier parsing and processing
    """
    zcat $archive | sed -E 's/^>gi\\|[0-9]+\\|gb\\|(\\w+)\\|(.*)/>\\1 \\2/' > influenza.fna
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        zcat: \$(echo \$(zcat --version 2>&1) | sed 's/^.*(gzip) //; s/ Copyright.*\$//')
    END_VERSIONS
    """
}

process CAT_CONSENSUS {
  tag "$sample"
  conda (params.enable_conda ? 'bioconda::shiptv=0.4.0' : null)
  if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
    container 'https://depot.galaxyproject.org/singularity/shiptv:0.4.0--pyh5e36f6f_0'
  } else {
    container 'quay.io/biocontainers/shiptv:0.4.0--pyh5e36f6f_0'
  }

  input:
  tuple val(sample), path(consensus)

  output:
  tuple val(sample), path('*.consensus.blastn.fasta'), emit: fasta
  path('*.consensus.fasta'), emit: consensus_fasta
  path "versions.yml" , emit: versions

  script:
  """
  cat_consensus_sequences.py \\
    --sample-name $sample \\
    --output1-fasta ${sample}.consensus.fasta \\
    --output2-fasta ${sample}.consensus.blastn.fasta \\
    $consensus

  cat <<-END_VERSIONS > versions.yml
  "${task.process}":
     python: \$(python --version | sed 's/Python //g')
  END_VERSIONS
  """
}



