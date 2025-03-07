# NecesseTranslationHelperScript

Simple PowerShell script to aid [Necesse](https://store.steampowered.com/app/1169040) game translation.

## Usage
In PowerShell, execute

```PowerShell
extract.ps1 \path\to\Necesse\locale
# Processes each {locale}.lang file
# extracts lines starting with "MISSING_TRANSLATE" 
# and writes them to 
# \path\to\Necesse\locale\missing_translations\{locale}_missing.lang

# when you finished translation

merge.ps1 \path\to\Necesse\locale
# Merges translation lines from 
# \path\to\Necesse\locale\missing_translations\{locale}_missing.lang
# into their corresponding source .lang files
```

Although `merge.ps1` creates backup file (`xxx.lang.bak`) by default, it's strongly recommended to manually copying your .lang files to a separate directory before running the script as an extra precaution.
