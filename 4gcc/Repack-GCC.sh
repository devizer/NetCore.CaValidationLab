set -e
set -u
set -o pipefail

function Trim-Files-Before-Repack() {
local files='./bin/7z
./bin/Drop-FS-Cache
./bin/File-IO-Benchmark
./bin/Get-Git-Tags
./bin/Get-GitHub-Latest-Release
./bin/Get-GitHub-Releases
./bin/Get-Local-Docker-Ip
./bin/Is-Docker-Container
./bin/Is-Fedora
./bin/Is-RedHat
./bin/MySQL-Container
./bin/Reset-Target-Framework
./bin/Say
./bin/Show-System-Stat
./bin/bunzip2
./bin/bzcat
./bin/bzcmp
./bin/bzdiff
./bin/bzegrep
./bin/bzfgrep
./bin/bzgrep
./bin/bzip2
./bin/bzip2recover
./bin/bzless
./bin/bzmore
./bin/git
./bin/git-cvsserver
./bin/git-receive-pack
./bin/git-shell
./bin/git-upload-archive
./bin/git-upload-pack
./bin/gitk
./bin/lazy-apt-update
./bin/list-packages
./bin/smart-apt-install
./bin/try-and-retry
./include/bzlib.h
./lib/libbz2.a
./lib/p7zip/7z
./lib/p7zip/7z.so
./lib/p7zip/7zCon.sfx
./lib/p7zip/Codecs/Rar.so
./libexec/git-core/git
./libexec/git-core/git-add
./libexec/git-core/git-add--interactive
./libexec/git-core/git-am
./libexec/git-core/git-annotate
./libexec/git-core/git-apply
./libexec/git-core/git-archimport
./libexec/git-core/git-archive
./libexec/git-core/git-bisect
./libexec/git-core/git-bisect--helper
./libexec/git-core/git-blame
./libexec/git-core/git-branch
./libexec/git-core/git-bugreport
./libexec/git-core/git-bundle
./libexec/git-core/git-cat-file
./libexec/git-core/git-check-attr
./libexec/git-core/git-check-ignore
./libexec/git-core/git-check-mailmap
./libexec/git-core/git-check-ref-format
./libexec/git-core/git-checkout
./libexec/git-core/git-checkout--worker
./libexec/git-core/git-checkout-index
./libexec/git-core/git-cherry
./libexec/git-core/git-cherry-pick
./libexec/git-core/git-citool
./libexec/git-core/git-clean
./libexec/git-core/git-clone
./libexec/git-core/git-column
./libexec/git-core/git-commit
./libexec/git-core/git-commit-graph
./libexec/git-core/git-commit-tree
./libexec/git-core/git-config
./libexec/git-core/git-count-objects
./libexec/git-core/git-credential
./libexec/git-core/git-credential-cache
./libexec/git-core/git-credential-cache--daemon
./libexec/git-core/git-credential-store
./libexec/git-core/git-cvsexportcommit
./libexec/git-core/git-cvsimport
./libexec/git-core/git-cvsserver
./libexec/git-core/git-daemon
./libexec/git-core/git-describe
./libexec/git-core/git-diff
./libexec/git-core/git-diff-files
./libexec/git-core/git-diff-index
./libexec/git-core/git-diff-tree
./libexec/git-core/git-difftool
./libexec/git-core/git-difftool--helper
./libexec/git-core/git-env--helper
./libexec/git-core/git-fast-export
./libexec/git-core/git-fast-import
./libexec/git-core/git-fetch
./libexec/git-core/git-fetch-pack
./libexec/git-core/git-filter-branch
./libexec/git-core/git-fmt-merge-msg
./libexec/git-core/git-for-each-ref
./libexec/git-core/git-for-each-repo
./libexec/git-core/git-format-patch
./libexec/git-core/git-fsck
./libexec/git-core/git-fsck-objects
./libexec/git-core/git-gc
./libexec/git-core/git-get-tar-commit-id
./libexec/git-core/git-grep
./libexec/git-core/git-gui
./libexec/git-core/git-gui--askpass
./libexec/git-core/git-hash-object
./libexec/git-core/git-help
./libexec/git-core/git-http-backend
./libexec/git-core/git-http-fetch
./libexec/git-core/git-http-push
./libexec/git-core/git-imap-send
./libexec/git-core/git-index-pack
./libexec/git-core/git-init
./libexec/git-core/git-init-db
./libexec/git-core/git-instaweb
./libexec/git-core/git-interpret-trailers
./libexec/git-core/git-log
./libexec/git-core/git-ls-files
./libexec/git-core/git-ls-remote
./libexec/git-core/git-ls-tree
./libexec/git-core/git-mailinfo
./libexec/git-core/git-mailsplit
./libexec/git-core/git-maintenance
./libexec/git-core/git-merge
./libexec/git-core/git-merge-base
./libexec/git-core/git-merge-file
./libexec/git-core/git-merge-index
./libexec/git-core/git-merge-octopus
./libexec/git-core/git-merge-one-file
./libexec/git-core/git-merge-ours
./libexec/git-core/git-merge-recursive
./libexec/git-core/git-merge-resolve
./libexec/git-core/git-merge-subtree
./libexec/git-core/git-merge-tree
./libexec/git-core/git-mergetool
./libexec/git-core/git-mergetool--lib
./libexec/git-core/git-mktag
./libexec/git-core/git-mktree
./libexec/git-core/git-multi-pack-index
./libexec/git-core/git-mv
./libexec/git-core/git-name-rev
./libexec/git-core/git-notes
./libexec/git-core/git-p4
./libexec/git-core/git-pack-objects
./libexec/git-core/git-pack-redundant
./libexec/git-core/git-pack-refs
./libexec/git-core/git-patch-id
./libexec/git-core/git-prune
./libexec/git-core/git-prune-packed
./libexec/git-core/git-pull
./libexec/git-core/git-push
./libexec/git-core/git-quiltimport
./libexec/git-core/git-range-diff
./libexec/git-core/git-read-tree
./libexec/git-core/git-rebase
./libexec/git-core/git-receive-pack
./libexec/git-core/git-reflog
./libexec/git-core/git-remote
./libexec/git-core/git-remote-ext
./libexec/git-core/git-remote-fd
./libexec/git-core/git-remote-ftp
./libexec/git-core/git-remote-ftps
./libexec/git-core/git-remote-http
./libexec/git-core/git-remote-https
./libexec/git-core/git-repack
./libexec/git-core/git-replace
./libexec/git-core/git-request-pull
./libexec/git-core/git-rerere
./libexec/git-core/git-reset
./libexec/git-core/git-restore
./libexec/git-core/git-rev-list
./libexec/git-core/git-rev-parse
./libexec/git-core/git-revert
./libexec/git-core/git-rm
./libexec/git-core/git-send-email
./libexec/git-core/git-send-pack
./libexec/git-core/git-sh-i18n
./libexec/git-core/git-sh-i18n--envsubst
./libexec/git-core/git-sh-setup
./libexec/git-core/git-shell
./libexec/git-core/git-shortlog
./libexec/git-core/git-show
./libexec/git-core/git-show-branch
./libexec/git-core/git-show-index
./libexec/git-core/git-show-ref
./libexec/git-core/git-sparse-checkout
./libexec/git-core/git-stage
./libexec/git-core/git-stash
./libexec/git-core/git-status
./libexec/git-core/git-stripspace
./libexec/git-core/git-submodule
./libexec/git-core/git-submodule--helper
./libexec/git-core/git-svn
./libexec/git-core/git-switch
./libexec/git-core/git-symbolic-ref
./libexec/git-core/git-tag
./libexec/git-core/git-unpack-file
./libexec/git-core/git-unpack-objects
./libexec/git-core/git-update-index
./libexec/git-core/git-update-ref
./libexec/git-core/git-update-server-info
./libexec/git-core/git-upload-archive
./libexec/git-core/git-upload-pack
./libexec/git-core/git-var
./libexec/git-core/git-verify-commit
./libexec/git-core/git-verify-pack
./libexec/git-core/git-verify-tag
./libexec/git-core/git-web--browse
./libexec/git-core/git-whatchanged
./libexec/git-core/git-worktree
./libexec/git-core/git-write-tree
./libexec/git-core/mergetools/araxis
./libexec/git-core/mergetools/bc
./libexec/git-core/mergetools/codecompare
./libexec/git-core/mergetools/deltawalker
./libexec/git-core/mergetools/diffmerge
./libexec/git-core/mergetools/diffuse
./libexec/git-core/mergetools/ecmerge
./libexec/git-core/mergetools/emerge
./libexec/git-core/mergetools/examdiff
./libexec/git-core/mergetools/guiffy
./libexec/git-core/mergetools/gvimdiff
./libexec/git-core/mergetools/kdiff3
./libexec/git-core/mergetools/kompare
./libexec/git-core/mergetools/meld
./libexec/git-core/mergetools/nvimdiff
./libexec/git-core/mergetools/opendiff
./libexec/git-core/mergetools/p4merge
./libexec/git-core/mergetools/smerge
./libexec/git-core/mergetools/tkdiff
./libexec/git-core/mergetools/tortoisemerge
./libexec/git-core/mergetools/vimdiff
./libexec/git-core/mergetools/winmerge
./libexec/git-core/mergetools/xxdiff
./share/doc/p7zip/ChangeLog
./share/doc/p7zip/DOC/7zC.txt
./share/doc/p7zip/DOC/7zFormat.txt
./share/doc/p7zip/DOC/License.txt
./share/doc/p7zip/DOC/MANUAL/cmdline/commands/add.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/commands/bench.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/commands/delete.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/commands/extract.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/commands/extract_full.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/commands/hash.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/commands/index.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/commands/list.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/commands/rename.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/commands/style.css
./share/doc/p7zip/DOC/MANUAL/cmdline/commands/test.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/commands/update.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/exit_codes.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/index.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/style.css
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/ar_exclude.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/ar_include.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/ar_no.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/bb.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/bs.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/charset.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/exclude.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/include.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/index.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/large_pages.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/list_tech.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/method.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/output_dir.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/overwrite.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/password.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/recurse.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/sa.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/scc.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/scrc.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/sdel.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/sfx.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/shared.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/sni.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/sns.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/spf.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/ssc.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/stdin.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/stdout.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/stl.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/stop_switch.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/stx.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/style.css
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/type.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/update.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/volume.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/working_dir.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/switches/yes.htm
./share/doc/p7zip/DOC/MANUAL/cmdline/syntax.htm
./share/doc/p7zip/DOC/MANUAL/fm/about.htm
./share/doc/p7zip/DOC/MANUAL/fm/benchmark.htm
./share/doc/p7zip/DOC/MANUAL/fm/index.htm
./share/doc/p7zip/DOC/MANUAL/fm/menu.htm
./share/doc/p7zip/DOC/MANUAL/fm/options.htm
./share/doc/p7zip/DOC/MANUAL/fm/plugins/7-zip/add.htm
./share/doc/p7zip/DOC/MANUAL/fm/plugins/7-zip/extract.htm
./share/doc/p7zip/DOC/MANUAL/fm/plugins/7-zip/index.htm
./share/doc/p7zip/DOC/MANUAL/fm/plugins/7-zip/style.css
./share/doc/p7zip/DOC/MANUAL/fm/plugins/index.htm
./share/doc/p7zip/DOC/MANUAL/fm/plugins/style.css
./share/doc/p7zip/DOC/MANUAL/fm/style.css
./share/doc/p7zip/DOC/MANUAL/general/7z.htm
./share/doc/p7zip/DOC/MANUAL/general/faq.htm
./share/doc/p7zip/DOC/MANUAL/general/formats.htm
./share/doc/p7zip/DOC/MANUAL/general/index.htm
./share/doc/p7zip/DOC/MANUAL/general/license.htm
./share/doc/p7zip/DOC/MANUAL/general/performance.htm
./share/doc/p7zip/DOC/MANUAL/general/style.css
./share/doc/p7zip/DOC/MANUAL/general/thanks.htm
./share/doc/p7zip/DOC/MANUAL/start.htm
./share/doc/p7zip/DOC/MANUAL/style.css
./share/doc/p7zip/DOC/Methods.txt
./share/doc/p7zip/DOC/copying.txt
./share/doc/p7zip/DOC/lzma.txt
./share/doc/p7zip/DOC/readme.txt
./share/doc/p7zip/DOC/src-history.txt
./share/doc/p7zip/DOC/unRarLicense.txt
./share/doc/p7zip/README
./share/git-core/templates/description
./share/git-core/templates/hooks/applypatch-msg.sample
./share/git-core/templates/hooks/commit-msg.sample
./share/git-core/templates/hooks/fsmonitor-watchman.sample
./share/git-core/templates/hooks/post-update.sample
./share/git-core/templates/hooks/pre-applypatch.sample
./share/git-core/templates/hooks/pre-commit.sample
./share/git-core/templates/hooks/pre-merge-commit.sample
./share/git-core/templates/hooks/pre-push.sample
./share/git-core/templates/hooks/pre-rebase.sample
./share/git-core/templates/hooks/pre-receive.sample
./share/git-core/templates/hooks/prepare-commit-msg.sample
./share/git-core/templates/hooks/push-to-checkout.sample
./share/git-core/templates/hooks/update.sample
./share/git-core/templates/info/exclude
./share/git-gui/lib/about.tcl
./share/git-gui/lib/blame.tcl
./share/git-gui/lib/branch.tcl
./share/git-gui/lib/branch_checkout.tcl
./share/git-gui/lib/branch_create.tcl
./share/git-gui/lib/branch_delete.tcl
./share/git-gui/lib/branch_rename.tcl
./share/git-gui/lib/browser.tcl
./share/git-gui/lib/checkout_op.tcl
./share/git-gui/lib/choose_font.tcl
./share/git-gui/lib/choose_repository.tcl
./share/git-gui/lib/choose_rev.tcl
./share/git-gui/lib/chord.tcl
./share/git-gui/lib/class.tcl
./share/git-gui/lib/commit.tcl
./share/git-gui/lib/console.tcl
./share/git-gui/lib/database.tcl
./share/git-gui/lib/date.tcl
./share/git-gui/lib/diff.tcl
./share/git-gui/lib/encoding.tcl
./share/git-gui/lib/error.tcl
./share/git-gui/lib/git-gui.ico
./share/git-gui/lib/index.tcl
./share/git-gui/lib/line.tcl
./share/git-gui/lib/logo.tcl
./share/git-gui/lib/merge.tcl
./share/git-gui/lib/mergetool.tcl
./share/git-gui/lib/msgs/bg.msg
./share/git-gui/lib/msgs/de.msg
./share/git-gui/lib/msgs/el.msg
./share/git-gui/lib/msgs/fr.msg
./share/git-gui/lib/msgs/hu.msg
./share/git-gui/lib/msgs/it.msg
./share/git-gui/lib/msgs/ja.msg
./share/git-gui/lib/msgs/nb.msg
./share/git-gui/lib/msgs/pt_br.msg
./share/git-gui/lib/msgs/pt_pt.msg
./share/git-gui/lib/msgs/ru.msg
./share/git-gui/lib/msgs/sv.msg
./share/git-gui/lib/msgs/vi.msg
./share/git-gui/lib/msgs/zh_cn.msg
./share/git-gui/lib/option.tcl
./share/git-gui/lib/remote.tcl
./share/git-gui/lib/remote_add.tcl
./share/git-gui/lib/remote_branch_delete.tcl
./share/git-gui/lib/search.tcl
./share/git-gui/lib/shortcut.tcl
./share/git-gui/lib/spellcheck.tcl
./share/git-gui/lib/sshkey.tcl
./share/git-gui/lib/status_bar.tcl
./share/git-gui/lib/tclIndex
./share/git-gui/lib/themed.tcl
./share/git-gui/lib/tools.tcl
./share/git-gui/lib/tools_dlg.tcl
./share/git-gui/lib/transport.tcl
./share/git-gui/lib/win32.tcl
./share/git-gui/lib/win32_shortcut.js
./share/gitk/lib/msgs/bg.msg
./share/gitk/lib/msgs/ca.msg
./share/gitk/lib/msgs/de.msg
./share/gitk/lib/msgs/es.msg
./share/gitk/lib/msgs/fr.msg
./share/gitk/lib/msgs/hu.msg
./share/gitk/lib/msgs/it.msg
./share/gitk/lib/msgs/ja.msg
./share/gitk/lib/msgs/pt_br.msg
./share/gitk/lib/msgs/pt_pt.msg
./share/gitk/lib/msgs/ru.msg
./share/gitk/lib/msgs/sv.msg
./share/gitk/lib/msgs/vi.msg
./share/gitk/lib/msgs/zh_cn.msg
./share/gitweb/gitweb.cgi
./share/gitweb/static/git-favicon.png
./share/gitweb/static/git-logo.png
./share/gitweb/static/gitweb.css
./share/gitweb/static/gitweb.js
./share/locale/bg/LC_MESSAGES/git.mo
./share/locale/ca/LC_MESSAGES/git.mo
./share/locale/de/LC_MESSAGES/git.mo
./share/locale/el/LC_MESSAGES/git.mo
./share/locale/es/LC_MESSAGES/git.mo
./share/locale/fr/LC_MESSAGES/git.mo
./share/locale/id/LC_MESSAGES/git.mo
./share/locale/is/LC_MESSAGES/git.mo
./share/locale/it/LC_MESSAGES/git.mo
./share/locale/ko/LC_MESSAGES/git.mo
./share/locale/pl/LC_MESSAGES/git.mo
./share/locale/pt_PT/LC_MESSAGES/git.mo
./share/locale/ru/LC_MESSAGES/git.mo
./share/locale/sv/LC_MESSAGES/git.mo
./share/locale/tr/LC_MESSAGES/git.mo
./share/locale/vi/LC_MESSAGES/git.mo
./share/locale/zh_CN/LC_MESSAGES/git.mo
./share/locale/zh_TW/LC_MESSAGES/git.mo
./share/perl5/FromCPAN/Error.pm
./share/perl5/FromCPAN/Mail/Address.pm
./share/perl5/Git.pm
./share/perl5/Git/I18N.pm
./share/perl5/Git/IndexInfo.pm
./share/perl5/Git/LoadCPAN.pm
./share/perl5/Git/LoadCPAN/Error.pm
./share/perl5/Git/LoadCPAN/Mail/Address.pm
./share/perl5/Git/Packet.pm
./share/perl5/Git/SVN.pm
./share/perl5/Git/SVN/Editor.pm
./share/perl5/Git/SVN/Fetcher.pm
./share/perl5/Git/SVN/GlobSpec.pm
./share/perl5/Git/SVN/Log.pm
./share/perl5/Git/SVN/Memoize/YAML.pm
./share/perl5/Git/SVN/Migration.pm
./share/perl5/Git/SVN/Prompt.pm
./share/perl5/Git/SVN/Ra.pm
./share/perl5/Git/SVN/Utils.pm'

for file in $files; do
  rm -f $file; # dir is not removed
done
}

script=https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash >/dev/null
Say --Reset-Stopwatch

for f in build-gcc-utilities.sh build-gcc-task.sh; do
  try-and-retry curl -kSL -o /tmp/$f https://raw.githubusercontent.com/devizer/NetCore.CaValidationLab/master/4gcc/$f
done
source /tmp/build-gcc-utilities.sh

DEPLOY_DIR="${DEPLOY_DIR:-/mnt/gcc-release}"
mkdir -p $DEPLOY_DIR

raw="$1"
ARTIFACT="${raw%.*}"; ARTIFACT="${ARTIFACT%.*}";
Say "Repack $raw --> $DEPLOY_DIR/$ARTIFACT.tar.gz and $DEPLOY_DIR/$ARTIFACT.tar.xz"


mkdir -p $DEPLOY_DIR
Say "Repack $raw"

work=/tmp/gcc-repack
mkdir -p $work
rm -rf $work/*

tar xzf $raw -C $work
chown -R root:root $work

pushd $work

Say "Check needed files in $(pwd)"
Trim-Files-Before-Repack # current folder matters

Say "Build uninstall-this-gcc.sh"
tar cf - . | gzip -1 > /tmp/temp-gcc-for-uninstall-script.tar.gz || true
generate_uninstall_this_gcc /tmp/temp-gcc-for-uninstall-script.tar.gz $work/uninstall-this-gcc.sh
rm -f /tmp/temp-gcc-for-uninstall-script.tar.gz
chmod +x $work/uninstall-this-gcc.sh

Say "pack release as gz"
tar cf - . | gzip -9 > $DEPLOY_DIR/$ARTIFACT.tar.gz
build_all_known_hash_sums $DEPLOY_DIR/$ARTIFACT.tar.gz

Say "pack release as xz"
tar cf - . | xz -z -9 -e > $DEPLOY_DIR/$ARTIFACT.tar.xz
build_all_known_hash_sums $DEPLOY_DIR/$ARTIFACT.tar.xz
popd
rm -rf $work/*
rm -rf $work/*

Say "Finished repack for $raw"
