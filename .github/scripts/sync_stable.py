"""Prepare the custom branch from an official stable release; no preview builds."""
import datetime
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import urllib.error
import urllib.request

BRANCH = 'custom-stable'


def api(path, missing_ok=False):
    request = urllib.request.Request('https://api.github.com/' + path, headers={
        'Authorization': 'Bearer ' + os.environ['GH_TOKEN'],
        'Accept': 'application/vnd.github+json',
    })
    try:
        with urllib.request.urlopen(request) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        if missing_ok and error.code == 404:
            return None
        raise


def stable_version(release):
    tag = release['tag_name']
    if release['draft'] or release['prerelease'] or not re.fullmatch(r'\d+\.\d+\.\d+\.\d+', tag):
        raise ValueError('Not an official stable version: ' + tag)
    if not any(a['name'] == f'NanaZip_{tag}.msixbundle' for a in release['assets']):
        raise ValueError('The stable MSIX bundle is not available yet.')
    return tag


def git(*args):
    return subprocess.check_output(['git', *args], text=True, encoding='utf-8').strip()


def write(path, content):
    Path(path).write_text(content, encoding='utf-8')


def pin_version(version):
    date = (datetime.date(2021, 8, 31) + datetime.timedelta(days=int(version.split('.')[2]))).isoformat()
    path = 'BuildAllTargets.proj'
    text = Path(path).read_text(encoding='utf-8-sig')
    for key, value in [('NanaZipBuildNumberDate', date), ('MileProjectVersion', version)]:
        text, count = re.subn(fr'<{key}>[^<]+</{key}>', f'<{key}>{value}</{key}>', text)
        if count != 1:
            raise ValueError('Expected one pinned ' + key)
    write(path, text)
    path = 'NanaZipPackage/Package.appxmanifest'
    text = Path(path).read_text(encoding='utf-8-sig')
    text, count = re.subn(r'(<Identity\b[^>]*\bVersion=")[^"]+("[^>]*>)',
                          lambda m: m[1] + version + m[2], text, flags=re.S)
    if count != 1 or 'Name="BrunoFaria.NanaZip"' not in text or 'Publisher="CN=Bruno Faria"' not in text:
        raise ValueError('The custom package identity was not preserved.')
    write(path, text)
    props = Path('NanaZip.Project/NanaZip.Project.props').read_text(encoding='utf-8-sig')
    if not re.search(r'<NanaZipBuildPreviewRelease\b[^>]*>false</NanaZipBuildPreviewRelease>', props):
        raise ValueError('Stable build mode must be enabled.')
    for path in ['Installer/README.txt', 'Documents/CustomBuild.md']:
        text = Path(path).read_text(encoding='utf-8-sig')
        text = re.sub(r'\d+\.\d+\.\d+\.\d+', version, text)
        if path.endswith('CustomBuild.md'):
            version_props = Path('NanaZip.Project/NanaZip.Project.Version.props')
            display = re.search(r'<NanaZipDisplayVersion>([^<]+)', version_props.read_text(encoding='utf-8-sig'))[1]
            text = re.sub(r'The upstream release is version `[^`]+`', f'The upstream release is version `{display}`', text)
        write(path, text)
    write(f'Installer/ReleaseNotes-{version}.md',
          f'NanaZip {version} — compilação estável personalizada.\n\n'
          f'Base oficial: https://github.com/M2Team/NanaZip/releases/tag/{version}\n\n'
          'Inclui as alterações da release oficial e preserva a barra de ferramentas personalizada, '
          'a identidade BrunoFaria.NanaZip e o editor Bruno Faria.\n\n'
          'Extraia o ZIP e execute `Install.cmd`. Inclui um certificado autoassinado público '
          'e um pacote para Windows x64 e ARM64. Verifique o ZIP com `SHA256SUMS.txt`.\n')


def prepare(version):
    # Fetch exactly the published tag, not the moving upstream main branch.
    git('fetch', '--no-tags', 'https://github.com/M2Team/NanaZip.git', f'refs/tags/{version}')
    upstream = git('rev-parse', 'FETCH_HEAD^{commit}')
    current = re.search(r'<MileProjectVersion>([^<]+)', Path('BuildAllTargets.proj').read_text(encoding='utf-8-sig'))[1]
    if tuple(map(int, version.split('.'))) < tuple(map(int, current.split('.'))):
        raise ValueError('Refusing to downgrade the custom branch.')
    if git('rev-list', '--count', f'HEAD..{upstream}') != '0':
        git('merge', upstream, '--no-commit', '--no-ff', '-X', 'ours')
        # GITHUB_TOKEN cannot change workflows. Keep the fork's automation intact.
        git('restore', '--source=HEAD', '--staged', '--worktree', '--', '.github')
        pin_version(version)
        git('add', '--all')
        git('commit', '-m', f'Merge official stable NanaZip {version}')
    else:
        pin_version(version)
        git('add', '--all')
        if git('diff', '--cached', '--name-only'):
            git('commit', '-m', f'Prepare stable NanaZip {version}')
    return git('rev-parse', 'HEAD')


def main():
    repo = os.environ['GITHUB_REPOSITORY']
    version = stable_version(api('repos/M2Team/NanaZip/releases/latest'))
    tag = f'v{version}-bf1'
    existing = api(f'repos/{repo}/releases/tags/{tag}', missing_ok=True)
    if existing and not existing['draft']:
        names = {a['name'] for a in existing['assets']}
        if existing['prerelease'] or not {f'NanaZip_{version}_Installer.zip', 'SHA256SUMS.txt'} <= names:
            raise ValueError('Existing published release is incomplete; manual inspection required.')
        print(f'{tag} is already published. No build needed.')
        return
    # Do not duplicate a manually launched version build already in progress.
    runs = api(f'repos/{repo}/actions/runs?branch=custom-{version}&per_page=20')['workflow_runs']
    if any(r['name'] == 'Build Binaries' and r['status'] != 'completed' for r in runs):
        print('The version build is already running; the next scheduled check will verify it.')
        return
    os.chdir(sys.argv[1])
    git('config', 'user.name', 'github-actions[bot]')
    git('config', 'user.email', '41898282+github-actions[bot]@users.noreply.github.com')
    if git('ls-remote', '--heads', 'origin', BRANCH):
        git('fetch', 'origin', BRANCH)
        git('checkout', '-B', BRANCH, 'FETCH_HEAD')
    else:
        git('checkout', '-B', BRANCH)
    sha = prepare(version)
    git('push', 'origin', f'HEAD:refs/heads/{BRANCH}')
    with open(os.environ['GITHUB_OUTPUT'], 'a', encoding='utf-8') as output:
        output.write(f'build=true\nversion={version}\nsha={sha}\n')
    print(f'Prepared {tag} at {sha}')


if __name__ == '__main__':
    main()
