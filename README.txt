CLMRS for iPhone - GitHub builds the unsigned IPA for you (free, no Mac or Xcode needed).

Upload these files to a GitHub repository:
  CLMRS.swift, Info.plist, the four AppIcon...png files,
  and the hidden .github folder.

1. Free account at github.com > New repository.
2. Add file > Upload files. Drag in every file from this folder.
   If ".github" didn't upload: Add file > Create new file, name it
       .github/workflows/build-ipa.yml
   and paste the text from build-ipa.yml.copy.txt.
3. Actions tab > "Build IPA" > Run workflow. Wait 3-5 minutes.
4. Open the finished run > Artifacts > CLMRS-ipa. Unzip to get CLMRS.ipa.
5. Open CLMRS.ipa in KSign, tap Sign, then Install.

If the build fails, open the failed run, copy the red "error:" lines and send them to Claude.
