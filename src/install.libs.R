# Install the DGGRID executable built by Makevars into the package's bin/.
exe <- file.path("dggrid", paste0("dggrid", if (WINDOWS) ".exe" else ""))
dest <- file.path(R_PACKAGE_DIR, "bin")
dir.create(dest, recursive = TRUE, showWarnings = FALSE)
file.copy(exe, dest, overwrite = TRUE)
Sys.chmod(file.path(dest, basename(exe)), "755")
