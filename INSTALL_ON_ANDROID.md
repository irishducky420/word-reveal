# Get Word Reveal on your Android phone (no tools needed)

The repo includes a GitHub Actions workflow that builds the APK on
GitHub's servers for free. One-time setup, ~10 minutes.

## 1. Put the project on GitHub
1. Go to https://github.com and sign in (or create a free account).
2. Click **+** (top right) → **New repository** → name it anything
   (e.g. `word-reveal`), Private is fine → **Create repository**.
3. On the new repo page, click the **"uploading an existing file"** link.
4. Unzip `word_reveal.zip` on your computer, open the `word_reveal`
   folder, select **everything inside it** (including the `.github`
   folder) and drag it onto the upload page. Click **Commit changes**.

   *If the `.github` folder didn't upload* (some browsers skip it):
   in the repo click **Add file → Create new file**, type
   `.github/workflows/build-apk.yml` as the name, and paste the contents
   of that file from the zip.

## 2. Let GitHub build it
1. Open the **Actions** tab of your repo. A "Build Android APK" run
   starts automatically (first build takes ~10 minutes — it also runs
   the full test suite).
2. When it shows a green check, click the run, scroll to **Artifacts**,
   and download **word-reveal-apk** (a zip containing
   `app-release.apk`).

   Tip: do this step in your phone's browser and you skip the
   cable/transfer entirely.

## 3. Install on the phone
1. Open the downloaded `app-release.apk` on the phone (unzip first if
   your browser kept it zipped — most file managers do this with a tap).
2. Android will ask to allow installs from your browser/file manager —
   allow it, then tap **Install**.

Notes
- The APK is signed with debug keys: perfect for your own phone, not
  accepted by the Play Store. Publishing later just means adding a real
  signing key — the workflow stays the same.
- Every future push to the repo rebuilds the APK automatically.
