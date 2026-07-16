import { describe, it, expect } from 'vitest';
import { detectLang, loadMessages } from '../src/i18n.js';

describe('detectLang', () => {
  it('prefers explicit flag', () => {
    expect(detectLang({ flag: 'pt-BR', env: { LANG: 'en_US.UTF-8' } })).toBe('pt-BR');
  });
  it('uses LC_ALL over LANG', () => {
    expect(detectLang({ env: { LC_ALL: 'es_ES.UTF-8', LANG: 'en_US.UTF-8' } })).toBe('es');
  });
  it('uses LANG when LC_ALL absent', () => {
    expect(detectLang({ env: { LANG: 'pt_BR.UTF-8' } })).toBe('pt-BR');
  });
  it('falls back to en for unknown locales', () => {
    expect(detectLang({ env: { LANG: 'xx_YY.UTF-8' } })).toBe('en');
  });
  it('matches by language prefix when region missing', () => {
    expect(detectLang({ flag: 'pt' })).toBe('pt-BR');
  });
  it('defaults to en when nothing provided', () => {
    expect(detectLang({ env: {} })).toBe('en');
  });
});

describe('loadMessages', () => {
  it('returns translated keys', () => {
    const m = loadMessages('pt-BR');
    expect(m.t('referencesHeading')).toBe('Referências');
  });
  it('falls back to en for missing keys', () => {
    const m = loadMessages('pt-BR');
    expect(m.t('__nonexistent__')).toBe('__nonexistent__');
  });
  it('interpolates {placeholders}', () => {
    const m = loadMessages('en');
    expect(m.t('cardDone', { percent: 42 })).toContain('42');
  });
  it('plural agreement via tp()', () => {
    const m = loadMessages('pt-BR');
    expect(m.tp('done', 1)).toBe('concluída');
    expect(m.tp('done', 2)).toBe('concluídas');
    expect(m.tp('done', 0)).toBe('concluídas');
  });
  it('exposes the resolved language', () => {
    expect(loadMessages('es').lang).toBe('es');
  });
});
