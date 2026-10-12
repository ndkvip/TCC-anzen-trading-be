import { validate } from 'class-validator';
import { JournalDto } from './journal.controller';

async function errors(notesDelta: unknown) {
  const dto = Object.assign(new JournalDto(), { notesDelta });
  return validate(dto);
}

describe('Journal notes validation', () => {
  it('accepts text, formatting and image inserts', async () => {
    expect(
      await errors([
        { insert: 'Ghi chú', attributes: { bold: true } },
        { insert: { image: 'https://drive.google.com/uc?id=test' } },
        { insert: '\n' },
      ]),
    ).toHaveLength(0);
  });
  it('rejects malformed operations and oversized notes', async () => {
    for (const delta of [
      null,
      {},
      [{ retain: 1 }],
      [{ insert: { video: 'x' } }],
      [{ insert: 'a', attributes: [] }],
      [{ insert: 'a'.repeat(100001) }],
    ]) {
      expect((await errors(delta)).length).toBeGreaterThan(0);
    }
  });
  it('allows omitted notes on partial updates', async () => {
    expect(
      await validate(Object.assign(new JournalDto(), { pnl: 0 })),
    ).toHaveLength(0);
  });
});
