import { describe, expect, test } from 'bun:test';
import { Glob } from 'bun';

// Hermes lacks the ES2023 copying array methods; bun has them, so tests alone would not catch it.
const UNSUPPORTED = /\.(toSorted|toReversed|toSpliced)\(/;

describe('Hermes compatibility', () => {
  test('app code avoids ES2023 copying array methods', async () => {
    const offenders: string[] = [];
    for (const dir of ['app', 'components', 'data', 'domain', 'lib', 'store'])
      for await (const file of new Glob(`${dir}/**/*.{ts,tsx}`).scan('.'))
        if (UNSUPPORTED.test(await Bun.file(file).text())) offenders.push(file);
    expect(offenders).toEqual([]);
  });
});
