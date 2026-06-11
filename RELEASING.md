# Releasing ccline

The install command is pinned to a release tag, so cutting a release means
bumping that pinned version everywhere and publishing a new tag.

## The easy way

```sh
./release.sh v0.2.0 "What changed in this release."
```

That script:

1. Validates the version (`vX.Y.Z`) and checks preconditions — clean working
   tree, the tag doesn't already exist, and `tests/test_ccline.fish` passes.
2. Bumps the pinned version in `install.fish` (the `REF` default) and `README.md`
   (the one-liner URL).
3. Commits and pushes `main`.
4. Creates and pushes the git tag.
5. Creates the GitHub release, including the pinned install one-liner.

Release notes are optional; pass them as the second argument (otherwise a
generic note is used). Edit them afterward on the release page if you like.

## The manual way

If you'd rather do it by hand (current version is `$CUR`, new is `$NEW`):

```sh
# 1. bump both references
perl -i -pe 's/\Q$CUR\E/$NEW/g' install.fish README.md

# 2. commit + push
git add -A && git commit -m "Release $NEW" && git push origin main

# 3. tag + push
git tag -a "$NEW" -m "ccline $NEW" && git push origin "$NEW"

# 4. GitHub release
gh release create "$NEW" --title "ccline $NEW" --notes "…"
```

## Notes

- **Versioning:** semantic versioning (`vMAJOR.MINOR.PATCH`). Bump PATCH for
  fixes, MINOR for new features, MAJOR for breaking changes to the install path
  or behavior.
- **Why pin:** the published `curl … | bash` URL points at a tag, so existing
  install instructions keep producing the same result even as `main` moves on.
  Users who want the latest dev build can override with
  `CCLINE_REF=main`.
- **Requirements to release:** `gh` authenticated, push access to
  `light4/ccline.fish`, `fish` and `perl` on PATH.
