import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import sync_stable as sync


class StableSyncTests(unittest.TestCase):
    def release(self):
        return dict(tag_name='7.0.1843.0', draft=False, prerelease=False,
                    assets=[dict(name='NanaZip_7.0.1843.0.msixbundle')])

    def test_only_complete_stable_release(self):
        self.assertEqual(sync.stable_version(self.release()), '7.0.1843.0')
        for changes in [dict(prerelease=True), dict(draft=True), dict(assets=[]),
                        dict(tag_name='7.0-preview'), dict(assets=[dict(name='NanaZipPreview_7.0.1843.0.msixbundle')])]:
            release = self.release() | changes
            with self.assertRaises(ValueError):
                sync.stable_version(release)

    def test_existing_release_skips_build_and_failed_api_is_not_missing(self):
        published = dict(draft=False, prerelease=False, assets=[
            dict(name='NanaZip_7.0.1843.0_Installer.zip'), dict(name='SHA256SUMS.txt')])
        with patch.dict(os.environ, GITHUB_REPOSITORY='test/fork'), patch.object(sync, 'git') as git:
            with patch.object(sync, 'api', side_effect=[self.release(), published]):
                sync.main()
            git.assert_not_called()
            with patch.object(sync, 'api', side_effect=RuntimeError('API unavailable')):
                with self.assertRaises(RuntimeError):
                    sync.main()

    def test_running_manual_build_skips_duplicate(self):
        runs = dict(workflow_runs=[dict(name='Build Binaries', status='in_progress')])
        with patch.dict(os.environ, GITHUB_REPOSITORY='test/fork'), patch.object(sync, 'git') as git:
            with patch.object(sync, 'api', side_effect=[self.release(), None, runs]):
                sync.main()
            git.assert_not_called()

    def test_real_merge_preserves_workflows_and_identity_and_can_retry(self):
        previous = os.getcwd()
        with tempfile.TemporaryDirectory() as folder:
            try:
                os.chdir(folder)
                sync.git('init')
                sync.git('config', 'user.name', 'Test')
                sync.git('config', 'user.email', 'test@example.invalid')
                files = {
                    'BuildAllTargets.proj': '<Project><NanaZipBuildNumberDate>2026-09-06</NanaZipBuildNumberDate><MileProjectVersion>7.0.1832.0</MileProjectVersion></Project>',
                    'NanaZipPackage/Package.appxmanifest': '<Package><Identity Name="Official" Publisher="CN=Official" Version="7.0.1832.0" /></Package>',
                    'NanaZip.Project/NanaZip.Project.props': '<Project><NanaZipBuildPreviewRelease>false</NanaZipBuildPreviewRelease></Project>',
                    'NanaZip.Project/NanaZip.Project.Version.props': '<Project><NanaZipDisplayVersion>2609.2</NanaZipDisplayVersion></Project>',
                    '.github/workflows/build.yml': 'upstream workflow\n',
                    'Installer/README.txt': '7.0.1832.0',
                    'Documents/CustomBuild.md': '7.0.1832.0 2609.1',
                    'source.cpp': 'old code\n',
                }
                for name, content in files.items():
                    Path(name).parent.mkdir(parents=True, exist_ok=True)
                    sync.write(name, content)
                sync.git('add', '.')
                sync.git('commit', '-m', 'base')
                sync.git('branch', 'upstream')
                sync.git('checkout', '-b', 'custom')
                sync.write('NanaZipPackage/Package.appxmanifest', files['NanaZipPackage/Package.appxmanifest'].replace('Name="Official"', 'Name="BrunoFaria.NanaZip"').replace('CN=Official', 'CN=Bruno Faria'))
                sync.write('.github/workflows/build.yml', 'custom workflow\n')
                sync.git('commit', '-am', 'customizations')
                sync.git('checkout', 'upstream')
                sync.write('source.cpp', 'fixed ZIP code\n')
                sync.write('.github/workflows/build.yml', 'changed upstream workflow\n')
                sync.write('NanaZipPackage/Package.appxmanifest', files['NanaZipPackage/Package.appxmanifest'].replace('1832', '1843'))
                sync.git('commit', '-am', 'new stable')
                sync.git('tag', '7.0.1843.0')
                upstream = sync.git('rev-parse', 'HEAD')
                sync.git('checkout', 'custom')
                real_git = sync.git

                def local_git(*args):
                    if args[0] == 'fetch':
                        return real_git('fetch', '.', 'refs/tags/7.0.1843.0')
                    return real_git(*args)

                with patch.object(sync, 'git', side_effect=local_git):
                    first = sync.prepare('7.0.1843.0')
                    self.assertEqual(sync.prepare('7.0.1843.0'), first)
                self.assertEqual(Path('source.cpp').read_text(), 'fixed ZIP code\n')
                self.assertEqual(Path('.github/workflows/build.yml').read_text(), 'custom workflow\n')
                self.assertIn('BrunoFaria.NanaZip', Path('NanaZipPackage/Package.appxmanifest').read_text())
                self.assertIn('7.0.1843.0', Path('NanaZipPackage/Package.appxmanifest').read_text())
                self.assertIn('2026-09-17', Path('BuildAllTargets.proj').read_text())
                self.assertEqual(real_git('rev-list', '--count', f'HEAD..{upstream}'), '0')
            finally:
                os.chdir(previous)


if __name__ == '__main__':
    unittest.main()
