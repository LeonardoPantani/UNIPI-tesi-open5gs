# UNIPI – Post-Quantum Open5GS Experimental Fork

This repository is a research fork of Open5GS developed for the Master's Thesis:

**Post-Quantum Cryptography in 5G Core Networks: Implementation and Cost Analysis in Open5GS**

The objective of this fork is not only to integrate Post-Quantum Cryptography into Open5GS, but to provide a fully automated and reproducible benchmarking environment for evaluating PQC algorithms impact on links between NFs of the 5G SA Architecture.


# Overview

This fork extends Open5GS with:

* Post-Quantum KEM and Digital Signature support in TLS 1.3
* OpenSSL rebuilt with oqsprovider
* Instrumented TLS handshake measurements
* Automated test execution and monitoring scripts
* Raw experimental datasets
* Data analysis scripts

This repository therefore contains both a modified 5G Core implementation and a complete experimental framework.


# Installation

## custom-install.sh

This script automates the full environment setup through guided steps.

It performs:

* Installation of required system dependencies
* Compilation and installation of liboqs
* Compilation of OpenSSL with oqsprovider enabled
* Configuration of environment variables
* Compilation of the modified Open5GS
* Setup of certificates and TLS configuration

---

# Source Code Modifications

## Main Modified Files

The most relevant changes are located in:

* `lib/sbi/client.c`
* `lib/sbi/nghttp2-server.c`

These files were extended to:

* Enable TLS 1.3 with PQC algorithms via OpenSSL + oqsprovider
* Allow configurable KEM and signature combinations
* Instrument TLS handshake timing

## PQC Bundle Changes

After completing the installation, move the contents of the `modified_pqc_bundle_files/pqc-bundle` folder into `install` folder to enable **primitive time measurements**. When prompted to replace existing files, confirm the overwrite.


# measurements_scripts Directory

The `measurements_scripts/` directory contains the automation layer used to execute all experiments described in the thesis.

The scripts allow:

* Running single UE registration experiments
* Running batch UE registration experiments
* Selecting classical or PQC algorithm combinations
* Enabling/disabling TLS session resumption
* Automatically collecting logs and metrics
* Structuring output data into reproducible folders

These scripts remove the need for manual orchestration of Network Functions and UERANSIM instances.

# measurements_results Directory

The `measurements_results/` directory contains:

* Raw logs from all experimental campaigns
* Structured CSV measurement files
* Intermediate processed datasets
* Final aggregated results used in thesis figures

All data used to produce thesis tables and graphs is included for transparency and reproducibility.

# Data Analysis

Python scripts included in the repository allow:

* Parsing raw Open5GS logs
* Extracting handshake times
* Computing statistical aggregates


# Reproducibility

This fork was designed with reproducibility as a primary goal. A researcher can:

1. Run `custom-install.sh`
2. Compile the modified Open5GS
3. Execute the measurement scripts
4. Collect structured results
5. Reproduce the full performance evaluation

The repository provides:

* A modified 5G Core implementation
* An automated benchmarking framework
* Complete raw datasets
* Analysis tools


# Scope

This repository is intended for:

* Researchers evaluating Post-Quantum Cryptography
* Performance benchmarking of TLS 1.3 with PQC
* 5G Core security experimentation
* Experimental validation of PQC in Service-Based Interfaces

It is not intended as a production-ready Open5GS replacement.