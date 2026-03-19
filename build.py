#!/usr/bin/env python3
"""
build.py - local PDF build for the ASML report.
Same steps as .github/workflows/build-report.yml but runs locally.

Requirements: a LaTeX distribution with pdflatex must be on PATH.
  Windows: MiKTeX (https://miktex.org) or TeX Live
  macOS:   MacTeX  (brew install --cask mactex)
  Linux:   texlive (sudo apt install texlive-full)

Usage:
  python build.py            # compile only
  python build.py --open     # compile and open the PDF
"""

import argparse
import os
import shutil
import subprocess
import sys

REPO_ROOT     = os.path.dirname(os.path.abspath(__file__))
REPORT_DIR    = os.path.join(REPO_ROOT, "ASML Report")
MAIN_TEX      = os.path.join(REPORT_DIR, "main.tex")
MAIN_PDF      = os.path.join(REPORT_DIR, "main.pdf")
OUTPUT_PDF    = os.path.join(REPO_ROOT, "ASML_Classification_Report.pdf")


def find_latex_engine():
    """Return the first available LaTeX engine."""
    for engine in ("pdflatex", "xelatex", "lualatex"):
        if shutil.which(engine):
            return engine
    return None


def compile_latex(engine):
    """Run the LaTeX engine twice (for cross-references / TOC)."""
    cmd = [engine, "-interaction=nonstopmode", "-halt-on-error", "main.tex"]
    for run in (1, 2):
        print(f"  [{run}/2] {engine} main.tex ...")
        result = subprocess.run(cmd, cwd=REPORT_DIR,
                                capture_output=True, text=True)
        if result.returncode != 0:
            # Print the last 40 lines of the log for context
            log_lines = result.stdout.splitlines()
            print("\n--- LaTeX error output (last 40 lines) ---")
            print("\n".join(log_lines[-40:]))
            print("------------------------------------------")
            sys.exit(f"\nBuild failed on run {run}. Fix the errors above.")


def copy_pdf():
    if not os.path.exists(MAIN_PDF):
        sys.exit("PDF not found after compilation.")
    shutil.copy2(MAIN_PDF, OUTPUT_PDF)
    size_kb = os.path.getsize(OUTPUT_PDF) // 1024
    print(f"  Copied to: ASML_Classification_Report.pdf  ({size_kb} KB)")


def open_pdf():
    """Open the PDF with the default viewer (cross-platform)."""
    if sys.platform == "win32":
        os.startfile(OUTPUT_PDF)
    elif sys.platform == "darwin":
        subprocess.run(["open", OUTPUT_PDF])
    else:
        subprocess.run(["xdg-open", OUTPUT_PDF])


def main():
    parser = argparse.ArgumentParser(description="Build the ASML report PDF locally.")
    parser.add_argument("--open", action="store_true",
                        help="Open the PDF after building")
    args = parser.parse_args()

    print("=== ASML Report - Local PDF Build ===\n")

    engine = find_latex_engine()
    if not engine:
        sys.exit(
            "No LaTeX engine found on PATH.\n"
            "Install MiKTeX (Windows), MacTeX (macOS), or texlive (Linux)."
        )
    print(f"LaTeX engine : {engine}")
    print(f"Report dir   : {REPORT_DIR}\n")

    print("Compiling LaTeX...")
    compile_latex(engine)

    print("\nCopying PDF to repo root...")
    copy_pdf()

    print("\nDone.")

    if args.open:
        print("Opening PDF...")
        open_pdf()


if __name__ == "__main__":
    main()
