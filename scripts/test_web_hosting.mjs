import assert from 'node:assert/strict';
import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

const repositoryRoot = fileURLToPath(new URL('../', import.meta.url));
const publicRoot = join(repositoryRoot, 'web');
const legacyPages = [
  ['privacy.html', 'プライバシーポリシー'],
  ['terms.html', '利用規約'],
  ['usage.html', 'アプリの使い方'],
  ['transfer.html', '端末引き継ぎ方法'],
  ['account-deletion.html', 'アカウント削除方法'],
  ['measurement-tips.html', '計測のコツ'],
];

function readPublicFile(filename) {
  return readFileSync(join(publicRoot, filename), 'utf8');
}

function collectPublicFiles(directory = publicRoot) {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const entryPath = join(directory, entry.name);
    assert.ok(!entry.isSymbolicLink(), `Public content must not be a symlink: ${entryPath}`);
    return entry.isDirectory() ? collectPublicFiles(entryPath) : [entryPath];
  });
}

function assertLocalReference(sourcePath, reference) {
  const sourceUrl = new URL(relative(publicRoot, sourcePath), 'https://physilog.example/');
  const targetUrl = new URL(reference.replaceAll('&amp;', '&'), sourceUrl);
  if (targetUrl.origin !== sourceUrl.origin) return;

  const targetPath = join(publicRoot, decodeURIComponent(targetUrl.pathname), targetUrl.pathname.endsWith('/') ? 'index.html' : '');
  assert.ok(existsSync(targetPath), `${sourceUrl.pathname} links to missing ${reference}`);
  assert.ok(statSync(targetPath).isFile(), `${reference} must resolve to a file`);
  if (targetUrl.hash && targetPath.endsWith('.html')) {
    const targetHtml = readFileSync(targetPath, 'utf8');
    const identifiers = [...targetHtml.matchAll(/\bid=["']([^"']+)["']/g)].map((match) => match[1]);
    assert.ok(identifiers.includes(decodeURIComponent(targetUrl.hash.slice(1))), `Missing anchor: ${reference}`);
  }
}

test('Firebase Hosting publishes web without an SPA fallback masking missing pages', () => {
  const configuration = JSON.parse(readFileSync(join(repositoryRoot, 'firebase.json'), 'utf8'));
  assert.equal(configuration.hosting.public, 'web');
  assert.ok(!configuration.hosting.rewrites?.some((rewrite) => rewrite.source === '**'));
});

test('developer docs do not keep a second copy of the public site', () => {
  assert.ok(!existsSync(join(repositoryRoot, 'docs/pages')));
});

test('the landing page has one main landmark and honest release navigation', () => {
  const html = readPublicFile('index.html');
  assert.match(html, /<html lang="ja">/);
  assert.equal((html.match(/<main(?:\s|>)/g) ?? []).length, 1);
  assert.ok(
    /<main\b[^>]*id="main-content"[^>]*tabindex="-1"/.test(html),
    'The skip link target must receive keyboard focus',
  );
  assert.equal((html.match(/<h1(?:\s|>)/g) ?? []).length, 1);
  assert.match(html, /href="support\.html"/);
  assert.match(html, /href="account-deletion\.html"/);
  assert.match(html, /公開予定/);
  assert.doesNotMatch(html, /事前登録|flutter_bootstrap/);
});

for (const [filename, title] of legacyPages) {
  test(`existing /${filename} remains available with its support backlink`, () => {
    const html = readPublicFile(filename);
    assert.ok(html.includes(`<h1>${title}</h1>`));
    assert.match(html, /href="support\.html">サポートトップへ戻る/);
    assert.match(html, /href="styles\.css"/);
  });
}

test('the support hub retains every existing destination and links to the LP', () => {
  const html = readPublicFile('support.html');
  for (const [filename] of legacyPages) {
    assert.ok(html.includes(`href="${filename}"`), `Missing support destination: ${filename}`);
  }
  assert.match(html, /href="index\.html"/);
});

test('all local links, fragments, stylesheets and images resolve within the public site', () => {
  const files = collectPublicFiles();
  assert.ok(files.some((filename) => filename.endsWith('.png')));
  for (const filename of files) {
    if (filename.endsWith('.html')) {
      const html = readFileSync(filename, 'utf8').replace(/<!--[\s\S]*?-->/g, '');
      assert.doesNotMatch(html, /https?:\/\/physilog-dev\.[^"'\s<]+/);
      for (const match of html.matchAll(/\b(?:href|src|poster)=["']([^"']+)["']/g)) {
        assertLocalReference(filename, match[1]);
      }
    } else if (filename.endsWith('.css')) {
      const css = readFileSync(filename, 'utf8').replace(/\/\*[\s\S]*?\*\//g, '');
      for (const match of css.matchAll(/url\(\s*["']?([^\s"')]+)["']?\s*\)/g)) {
        assertLocalReference(filename, match[1]);
      }
    }
    assert.ok(/\.(?:html|css|png)$/.test(filename), `Unexpected public file: ${filename}`);
  }
});

test('the LP offers visible keyboard focus and respects reduced motion', () => {
  const css = readPublicFile('style.css');
  assert.match(css, /:focus-visible/);
  assert.match(css, /prefers-reduced-motion:\s*reduce/);
  assert.match(css, /scroll-behavior:\s*auto/);
});

for (const environment of ['dev', 'prod']) {
  test(`${environment} Hosting deployment validates static content before publishing`, () => {
    const workflow = readFileSync(join(repositoryRoot, `.github/workflows/deploy_${environment}_hosting.yml`), 'utf8');
    const validation = workflow.indexOf('node --test scripts/test_web_hosting.mjs');
    const deployment = workflow.indexOf('firebase deploy --only hosting');
    assert.ok(validation >= 0 && validation < deployment);
    assert.match(workflow, /actions\/setup-node@/);
    assert.doesNotMatch(workflow, /docs\/pages/);
    if (environment === 'dev') {
      assert.match(workflow, /- web\/\*\*/);
      assert.match(workflow, /- scripts\/test_web_hosting\.mjs/);
    } else {
      assert.match(workflow, /workflow_dispatch:/);
      assert.doesNotMatch(workflow, /\bpush:/);
    }
  });
}

test('PR CI requires the public Web validation job', () => {
  const workflow = readFileSync(join(repositoryRoot, '.github/workflows/ci.yml'), 'utf8');
  assert.match(workflow, /node --test scripts\/test_web_hosting\.mjs/);
  assert.match(workflow, /needs: \[analyze, test, web\]/);
  assert.match(workflow, /needs\.web\.result/);
});
