# Repository Base Structure

This folder contains the standardized base repository structure required for Oracle APEX deployments. All new projects should mirror this layout to ensure compatibility with our CI/CD pipelines, automated scripts, and deployment strategies.

## Directory Layout

The core components of the repository structure are logically broken down by their database and application functions:

- **`apex/`**: Contains the exported Oracle APEX applications in `.sql` format.
- **`data/`**: Stores re-runnable data scripts, most commonly used for populating List of Values (LOV) / lookup tables.
- **`lib/`**: Contains 3rd party database libraries or utilities needed for the project.
- **`packages/`**: Stores `PL/SQL` package specifications (`.pks`) and bodies (`.pkb`). Ensure all packages follow the logging standards.
- **`release/`**: Contains the versioned release manifests and files used to govern the roll-out of database and APEX changes. See [Release README](release/README.md) for strategy details.
- **`scripts/`**: Houses utility execution scripts (e.g., standard scripts to disable an application during deployment, install APEX apps, etc.).
- **`synonyms/`**: Stores scripts for creating synonyms.
- **`triggers/`**: Stores all database triggers.
- **`views/`**: Stores view DDL statements.
- **`www/`**: Represents frontend assets. Custom JavaScript, CSS, and Images should be managed here and uploaded into the APEX workspace (or a web server) during build times.

## How to use this template

When creating or standardizing a new Oracle APEX project repository:

1. Ensure the root directory maintains these folder names.
2. Ensure you are familiar with the code-review processes prior to making pull requests into these folders.
3. Review the `/release` folder for understanding how changes transition from `Dev -> Test -> Prod` using the provided release deployment models.
