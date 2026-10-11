#!/usr/bin/env python3
"""Sintetiza o áudio PLACEHOLDER do Chernobyl Miner (efeitos, ambientes e trilhas).

Uso:  python tools/gen_audio.py
Substituir um som = sobrescrever o WAV com o mesmo nome (mono/estéreo, qualquer taxa).

Técnicas de horror usadas (ver pesquisa no README): drones graves de 30–60 Hz com
batimento (desconforto físico), camadas de ambiente, sons "humanos" quase reconhecíveis
(sussurro, respiração, voz no rádio), reverberação de túnel e silêncio.
"""
import math
import os
import random
import struct
import wave

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, '..', 'assets', 'audio'))
SR = 22050
TAU = math.tau


# =========================================================================== base
def write(rel, x, gain=0.85):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    peak = max(1e-6, max(abs(s) for s in x))
    k = gain / peak
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1.0, min(1.0, s * k)) * 32000)) for s in x))


def n_(sec):
    return int(sec * SR)


def silence(n):
    return [0.0] * n


def noise(n, rng):
    return [rng.uniform(-1, 1) for _ in range(n)]


def brown(n, rng, leak=0.995):
    y, out = 0.0, []
    for _ in range(n):
        y = y * leak + rng.uniform(-1, 1) * 0.06
        out.append(y)
    return out


def lp(x, a):
    y, out = 0.0, []
    for s in x:
        y += a * (s - y); out.append(y)
    return out


def hp(x, a):
    l = lp(x, a)
    return [s - v for s, v in zip(x, l)]


def bp(x, f, q=4.0):
    """Biquad passa-banda (RBJ)."""
    w0 = TAU * f / SR
    al = math.sin(w0) / (2 * q)
    b0, b1, b2 = al, 0.0, -al
    a0, a1, a2 = 1 + al, -2 * math.cos(w0), 1 - al
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    x1 = x2 = y1 = y2 = 0.0
    out = []
    for s in x:
        y = b0 * s + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, s, y1, y
        out.append(y)
    return out


def osc(n, freq, kind='sin', phase=0.0):
    out, ph = [], phase
    for i in range(n):
        f = freq(i / SR) if callable(freq) else freq
        ph += f / SR
        p = ph % 1.0
        if kind == 'sin':
            v = math.sin(ph * TAU)
        elif kind == 'saw':
            v = 2 * p - 1
        elif kind == 'sq':
            v = 1.0 if p < .5 else -1.0
        else:
            v = 4 * abs(p - .5) - 1
        out.append(v)
    return out


def env_exp(n, tau):
    return [math.exp(-i / (tau * SR)) for i in range(n)]


def env_ad(n, attack, decay_tau):
    a = max(1, n_(attack))
    return [(i / a) if i < a else math.exp(-(i - a) / (decay_tau * SR)) for i in range(n)]


def env_hann(n, power=1.0):
    return [max(0.0, math.sin(math.pi * i / max(1, n - 1))) ** power for i in range(n)]


def mulv(x, e):
    return [a * b for a, b in zip(x, e)]


def gain(x, g):
    return [s * g for s in x]


def add(*sigs):
    n = max(len(s) for s in sigs)
    out = [0.0] * n
    for s in sigs:
        for i, v in enumerate(s):
            out[i] += v
    return out


def place(dst, src, at, g=1.0):
    for i, v in enumerate(src):
        if 0 <= at + i < len(dst):
            dst[at + i] += v * g


def reverb(x, size=1.0, wet=0.35, tail=1.5):
    """Reverberação de Schroeder (4 combs + 2 allpass): eco de túnel."""
    x = x + [0.0] * n_(tail)
    combs = [int(1557 * size), int(1617 * size), int(1491 * size), int(1422 * size)]
    fb = 0.78
    out = [0.0] * len(x)
    for d in combs:
        buf = [0.0] * d
        idx = 0
        lpv = 0.0
        for i, s in enumerate(x):
            y = buf[idx]
            lpv = y * 0.6 + lpv * 0.4
            buf[idx] = s + lpv * fb
            idx = (idx + 1) % d
            out[i] += y * 0.25
    for d, g in ((225, 0.5), (556, 0.5)):
        buf = [0.0] * d
        idx = 0
        res = []
        for s in out:
            bv = buf[idx]
            y = -s * g + bv
            buf[idx] = s + bv * g
            idx = (idx + 1) % d
            res.append(y)
        out = res
    return [d * (1 - wet) + w * wet for d, w in zip(x, out)]


def loopable(x, fade):
    n = len(x) - fade
    out = x[:n]
    for i in range(fade):
        t = i / fade
        out[i] = x[i] * t + x[n + i] * (1 - t)
    return out


def norm(x, peak=1.0):
    m = max(1e-9, max(abs(v) for v in x))
    return [v * peak / m for v in x]


def karplus(freq, dur, rng, damp=0.996, bright=0.45):
    """Corda dedilhada (Karplus–Strong): bandura/violão distante."""
    n = n_(dur)
    N = max(2, int(round(SR / freq)))
    buf = lp([rng.uniform(-1, 1) for _ in range(N)], bright)
    out, idx = [], 0
    for _ in range(n):
        v = buf[idx]
        buf[idx] = damp * 0.5 * (v + buf[(idx + 1) % N])
        out.append(v)
        idx = (idx + 1) % N
    return out


def smooth_air(n, rng, cut=0.006):
    """Ar parado de túnel: ruído muito suavizado (sem o 'arrastado' do ruído marrom)."""
    return norm(lp(lp(noise(n, rng), cut), cut * 3), 1.0)


def formant_noise(n, rng, formants, wobble=0.0):
    """Ruído filtrado por formantes (soa como vogal sussurrada)."""
    src = noise(n, rng)
    out = silence(n)
    for f, g in formants:
        band = bp(src, f * (1 + wobble * rng.uniform(-1, 1)), 6.0)
        out = add(out, gain(band, g))
    return out


# ======================================================================= SFX
def build_sfx(rng):
    d = 'sfx/'
    for k in range(3):
        n = n_(.012)
        x = add(mulv(hp(noise(n, rng), .5), env_exp(n, .0012 + k * .0004)),
                mulv(gain(osc(n, 3200 + 600 * k), .5), env_exp(n, .002)))
        write(d + f'geiger_{k + 1}.wav', x)
    for k in range(3):                                   # golpe na rocha, com corpo grave
        n = n_(.3)
        thud = mulv(lp(noise(n, rng), .07), env_exp(n, .035))
        body = mulv(gain(osc(n, lambda t: 140 - 220 * t + 25 * k), .9), env_exp(n, .05))
        tick = mulv(gain(hp(noise(n, rng), .35), .45), env_exp(n, .008))
        grit = mulv(gain(bp(noise(n, rng), 900 + 300 * k, 2), .6), env_exp(n, .03))
        write(d + f'hit_rock_{k + 1}.wav', reverb(add(gain(thud, 2.3), body, tick, grit), .5, .18, .3))
    n = n_(.45)
    ring = add(gain(osc(n, 1250), .5), gain(osc(n, 2710), .33), gain(osc(n, 3930), .18))
    write(d + 'hit_metal.wav', reverb(add(mulv(ring, env_exp(n, .08)), mulv(gain(lp(noise(n, rng), .1), 1.4), env_exp(n, .02))), .6, .25, .4))
    n = n_(.3)
    write(d + 'hit_fail.wav', add(mulv(gain(osc(n, 2300), .6), env_exp(n, .03)), mulv(gain(osc(n, 3450), .4), env_exp(n, .02))))
    n = n_(.8)                                           # rocha quebrando (desmoronar curto)
    x = silence(n)
    for b in range(11):
        m = n_(.14)
        burst = mulv(lp(noise(m, rng), .05 + rng.random() * .18), env_exp(m, .028))
        place(x, burst, int(b * .045 * SR + rng.randint(0, 700)), (1 - b / 12) * 2)
    x = add(x, mulv(gain(osc(n, lambda t: 85 - 40 * t), .9), env_exp(n, .09)))
    write(d + 'rock_break.wav', reverb(x, .7, .22, .5))
    n = n_(.45)
    write(d + 'wood_break.wav', reverb(add(mulv(gain(lp(noise(n, rng), .25), 1.6), env_exp(n, .05)),
                                           mulv(gain(osc(n, 180), .5), env_exp(n, .04))), .5, .15, .3))
    n = n_(.12)                                          # coleta: clique metálico suave (nada de "moedinha")
    write(d + 'pickup.wav', add(mulv(gain(osc(n, 1650), .3), env_exp(n, .02)), mulv(gain(hp(noise(n, rng), .4), .3), env_exp(n, .004))))
    n = n_(1.4)                                          # achado raro: acorde menor tenso
    x = silence(n)
    for k, f in enumerate((440, 523, 622)):
        place(x, mulv(gain(osc(n, f, 'tri'), .25), env_ad(n, .01, .5)), n_(k * .05))
    write(d + 'rare_find.wav', reverb(x, 1.0, .4, 1.0))
    for k in range(3):
        n = n_(.1)
        write(d + f'step_{k + 1}.wav', gain(mulv(lp(noise(n, rng), .11 + k * .04), env_exp(n, .02)), .9))
    n = n_(.28)
    write(d + 'swing.wav', gain(mulv(bp(noise(n, rng), 700, 1.2), env_hann(n, 2)), .8))
    n = n_(.035)                                         # interface: relés e botões físicos
    write(d + 'ui_click.wav', add(mulv(hp(noise(n, rng), .5), env_exp(n, .003)), mulv(gain(osc(n, 900, 'sq'), .2), env_exp(n, .004))))
    n = n_(.02)
    write(d + 'ui_hover.wav', mulv(gain(osc(n, 2400), .2), env_exp(n, .004)))
    n = n_(.25)
    write(d + 'ui_open.wav', add(mulv(gain(osc(n, lambda t: 220 + 400 * t, 'sq'), .15), env_exp(n, .06)), mulv(lp(noise(n, rng), .2), env_exp(n, .02))))
    n = n_(.4)
    write(d + 'ui_buy.wav', add(mulv(gain(osc(n, 660, 'tri'), .4), env_exp(n, .08)), [0.0] * n_(.08) + mulv(gain(osc(n, 880, 'tri'), .4), env_exp(n, .1))))
    n = n_(.25)
    write(d + 'ui_error.wav', lp(mulv(gain(osc(n, 110, 'sq'), .4), env_exp(n, .12)), .2))
    n = n_(.5)
    x = silence(n)
    for b in range(5):
        m = n_(.1)
        place(x, mulv(add(gain(osc(m, 2200 + rng.randint(0, 600)), .25), gain(hp(noise(m, rng), .5), .2)), env_exp(m, .02)), n_(b * .055))
    write(d + 'sell.wav', x)
    n = n_(.9)                                           # nova missão: sino grave + chiado
    write(d + 'quest.wav', reverb(add(mulv(gain(osc(n, 196, 'tri'), .5), env_ad(n, .005, .35)), mulv(gain(osc(n, 294, 'tri'), .3), env_ad(n, .005, .3))), 1.0, .35, .8))
    n = n_(1.4)
    x = silence(n)
    for k, f in enumerate((196, 247, 294, 392)):
        place(x, mulv(gain(osc(n, f, 'tri'), .22), env_ad(n, .01, .5)), n_(k * .09))
    write(d + 'quest_done.wav', reverb(x, 1.0, .35, .8))
    n = n_(.018)
    write(d + 'text_blip.wav', mulv(gain(osc(n, 1100, 'sq'), .2), env_exp(n, .006)))
    n = n_(.18)
    write(d + 'terminal_beep.wav', mulv(gain(osc(n, 1600, 'sq'), .25), [1.0 if i < n * .8 else 0 for i in range(n)]))
    n = n_(.12)
    write(d + 'alarm_beep.wav', mulv(gain(osc(n, 2100, 'sq'), .25), [1.0 if i < n * .85 else 0 for i in range(n)]))
    n = n_(.55)
    write(d + 'ladder.wav', reverb(add(mulv(gain(osc(n, lambda t: 210 + 70 * math.sin(t * 40)), .2), env_exp(n, .15)),
                                       mulv(lp(noise(n, rng), .05), env_exp(n, .1))), .6, .25, .4))
    n = n_(.4)
    write(d + 'door.wav', add(mulv(gain(lp(noise(n, rng), .04), 3), env_exp(n, .05)), mulv(gain(osc(n, 70), .8), env_exp(n, .08))))
    n = n_(2.4)                                          # porta pesada (hermética)
    x = add(mulv(gain(osc(n, lambda t: 55 + 20 * t), .7), env_ad(n, .02, .9)),
            mulv(gain(bp(noise(n, rng), 300, 3), 1.2), env_ad(n, .4, .5)),
            mulv(gain(osc(n, lambda t: 380 - 60 * t + 12 * math.sin(t * 9), 'saw'), .08), env_hann(n)))
    write(d + 'door_heavy.wav', reverb(x, 1.3, .4, 1.5))
    n = n_(2.2)
    x = silence(n)
    for k, f in enumerate((131, 156, 196)):
        place(x, mulv(gain(osc(n, f, 'tri'), .2), [min(1, i / (.2 * SR)) * math.exp(-i / (.9 * SR)) for i in range(n)]), n_(k * .25))
    write(d + 'sleep.wav', reverb(x, 1.2, .4, 1.0))
    n = n_(1.6)
    write(d + 'passout.wav', reverb(add(mulv(gain(lp(noise(n, rng), .03), 3), env_exp(n, .2)), mulv(gain(osc(n, 3100), .12), env_exp(n, .8))), 1.2, .4, 1.0))
    n = n_(.25)
    write(d + 'hurt.wav', lp(mulv(gain(osc(n, lambda t: 260 - 500 * t, 'sq'), .4), env_exp(n, .08)), .3))
    n = n_(.5)
    write(d + 'paper.wav', mulv(gain(hp(noise(n, rng), .6), .4), env_hann(n, 3)))
    n = n_(.6)                                           # fita: clique do botão + motor
    x = add(mulv(hp(noise(n, rng), .3), env_exp(n, .01)), mulv(gain(osc(n, 55, 'sq'), .05), env_hann(n)),
            mulv(gain(hp(noise(n, rng), .7), .15), [min(1, i / (.1 * SR)) for i in range(n)]))
    write(d + 'tape.wav', x)
    n = n_(.7)
    write(d + 'radio_burst.wav', mulv(add(gain(hp(noise(n, rng), .4), .6), gain(osc(n, lambda t: 900 + 400 * math.sin(t * 30), 'sq'), .1)), env_hann(n, .5)))
    n = n_(.06)
    write(d + 'radio_tick.wav', mulv(gain(hp(noise(n, rng), .5), .4), env_exp(n, .01)))
    n = n_(3.0)                                          # stinger: impacto grave + cluster dissonante
    x = add(mulv(gain(osc(n, lambda t: 48 - 10 * t), 1.0), env_ad(n, .005, .8)),
            mulv(gain(lp(noise(n, rng), .05), 1.5), env_exp(n, .3)))
    for f in (233, 247, 262, 330):
        x = add(x, mulv(gain(osc(n, f, 'saw'), .05), env_ad(n, .8, 1.0)))
    write(d + 'stinger.wav', reverb(lp(x, .3), 1.4, .45, 1.5))
    n = n_(2.5)
    x = add(mulv(gain(osc(n, 62), .6), env_ad(n, .4, .8)), mulv(gain(osc(n, 93), .3), env_ad(n, .6, .8)),
            mulv(gain(osc(n, 98), .25), env_ad(n, .6, .8)))
    write(d + 'stinger_soft.wav', reverb(x, 1.3, .45, 1.2))
    n = n_(.9)
    write(d + 'steam_burst.wav', mulv(gain(hp(noise(n, rng), .55), .6), env_ad(n, .05, .3)))
    n = n_(.3)
    x = silence(n)
    for _ in range(6):
        place(x, mulv(hp(noise(n_(.02), rng), .6), env_exp(n_(.02), .004)), rng.randrange(0, n - n_(.02)))
    write(d + 'spark.wav', add(x, mulv(gain(osc(n, 120, 'sq'), .1), env_exp(n, .05))))
    for k in range(2):
        n = n_(.6)
        write(d + f'drip_{k + 1}.wav', reverb(mulv(gain(osc(n, lambda t: 1500 + 700 * k + 900 * math.exp(-t * 35)), .35), env_exp(n, .04)), .8, .4, .6))
    for k in range(2):                                   # sussurros (formantes de vogais sussurradas)
        n = n_(2.2)
        x = silence(n)
        t0 = 0
        for syl in range(rng.randint(5, 8)):
            m = n_(rng.uniform(.12, .3))
            vowel = rng.choice([[(700, 1.0), (1200, .7), (2600, .3)], [(300, 1.0), (2300, .6), (3000, .3)],
                                [(500, 1.0), (900, .8), (2400, .25)], [(350, 1.0), (800, .6), (2400, .2)]])
            place(x, mulv(formant_noise(m, rng, vowel, .05), env_hann(m, 1.5)), t0, rng.uniform(.5, 1.0))
            t0 += m + n_(rng.uniform(.02, .1))
        write(d + f'whisper_{k + 1}.wav', reverb(x, 1.2, .5, 1.5))
    n = n_(2.0)                                          # três batidas dentro da rocha
    x = silence(n)
    for k in range(3):
        m = n_(.25)
        place(x, add(mulv(gain(lp(noise(m, rng), .06), 2), env_exp(m, .025)), mulv(gain(osc(m, 95), 1), env_exp(m, .04))), n_(k * .55))
    write(d + 'knock.wav', reverb(x, 1.3, .45, 1.2))
    n = n_(1.6)                                          # alguém chama (vogais distorcidas, longe)
    x = silence(n)
    for k, (dur, vowel, pitch) in enumerate(((.35, [(600, 1), (1100, .6)], 180), (.55, [(450, 1), (800, .7)], 150))):
        m = n_(dur)
        voiced = gain(osc(m, lambda t, p=pitch: p - 25 * t + 4 * math.sin(t * 30), 'saw'), .5)
        v = silence(m)
        for f, g in vowel:
            v = add(v, gain(bp(voiced, f, 5), g))
        place(x, mulv(add(v, gain(formant_noise(m, rng, vowel), .4)), env_hann(m, 1.2)), n_(k * .45))
    write(d + 'name_call.wav', reverb(lp(x, .5), 1.5, .6, 1.8))
    n = n_(2.6)                                          # voz no rádio: ruído modulado em ritmo de fala
    voice = silence(n)
    t0 = n_(.2)
    while t0 < n - n_(.3):
        m = n_(rng.uniform(.08, .22))
        vowel = rng.choice([[(700, 1.0), (1200, .7)], [(400, 1.0), (2000, .5)], [(550, 1.0), (900, .8)]])
        buzz = gain(osc(m, lambda t: 140 + 20 * math.sin(t * 13), 'sq'), .3)
        syl = silence(m)
        for f, g in vowel:
            syl = add(syl, gain(bp(buzz, f, 4), g))
        place(voice, mulv(syl, env_hann(m)), t0)
        t0 += m + n_(rng.uniform(.03, .15))
    stat = gain(hp(noise(n, rng), .45), .35)
    am = [.6 + .4 * math.sin(i / SR * TAU * 6.3) for i in range(n)]
    write(d + 'radio_voice.wav', add(mulv(bp(voice, 1200, .7), am), stat))
    n = n_(1.5)
    write(d + 'power_down.wav', add(mulv(gain(osc(n, lambda t: 120 * math.exp(-t * 2.2) + 20, 'saw'), .4), env_exp(n, .6)),
                                    mulv(gain(hp(noise(n, rng), .5), .2), env_exp(n, .05))))
    n = n_(3.6)                                          # tremor: ronco grave liso + poeira caindo, sem estalos
    e = [min(1, i / (.35 * SR)) * (1 if i < n * .45 else math.exp(-(i - n * .45) / (.7 * SR))) for i in range(n)]
    rum = gain(smooth_air(n, rng, .004), .9)
    sub = add(gain(osc(n, lambda t: 31 + 3 * math.sin(t * 2.3)), .8), gain(osc(n, lambda t: 46 + 2 * math.sin(t * 1.7)), .35))
    am = [.75 + .25 * math.sin(i / SR * TAU * 5.5) * math.sin(i / SR * TAU * .9) for i in range(n)]
    x = mulv(add(rum, mulv(sub, am)), e)
    for _ in range(7):
        m = n_(.18)
        place(x, mulv(lp(noise(m, rng), .05), env_exp(m, .05)), rng.randrange(n_(.4), n - m), rng.uniform(.08, .2))
    write(d + 'quake.wav', reverb(lp(x, .12), 1.3, .3, .8), .8)
    for k in range(2):                                   # rangidos (madeira/metal sob pressão)
        n = n_(1.7)
        base = 120 + 40 * k
        x = mulv(gain(osc(n, lambda t, b=base: b + 45 * math.sin(t * 3) + 9 * math.sin(t * 61), 'saw'), .25), env_hann(n))
        write(d + f'creak_{k + 1}.wav', reverb(bp(x, 500 + 200 * k, 2), 1.1, .45, 1.2))
    n = n_(3.2)                                          # gemido metálico distante
    x = add(mulv(gain(osc(n, lambda t: 70 + 18 * math.sin(t * 1.3), 'saw'), .3), env_hann(n, 1.5)),
            mulv(gain(osc(n, lambda t: 311 + 25 * math.sin(t * 2.1)), .12), env_hann(n, 2)),
            mulv(gain(osc(n, lambda t: 467 + 30 * math.sin(t * 1.7)), .08), env_hann(n, 2)))
    write(d + 'metal_groan.wav', reverb(lp(x, .2), 1.6, .55, 2.0))
    n = n_(1.5)
    write(d + 'distant_bang.wav', reverb(lp(add(mulv(gain(lp(noise(n, rng), .05), 2), env_exp(n, .08)), mulv(gain(osc(n, 45), 1), env_exp(n, .2))), .1), 1.6, .6, 2.0))
    n = n_(6.0)                                          # sirene distante
    x = mulv(gain(osc(n, lambda t: 430 + 170 * math.sin(math.pi * t / 6 * 2 - math.pi / 2), 'tri'), .3), env_hann(n))
    write(d + 'siren_distant.wav', reverb(lp(x, .1), 1.6, .55, 2.0))
    n = n_(3.0)                                          # cachorro uivando longe
    x = mulv(gain(osc(n, lambda t: 520 + 160 * math.sin(min(t, 2.6) * 1.2) - 90 * max(0, t - 2.2)), .3), env_hann(n, .8))
    x = add(bp(x, 700, 1.5), gain(bp(x, 1400, 3), .3))
    write(d + 'dog_howl.wav', reverb(lp(x, .25), 1.8, .65, 2.2))
    n = n_(2.5)
    write(d + 'wind_gust.wav', mulv(gain(bp(noise(n, rng), 500, .8), 1.0), env_hann(n, 1.5)))
    n = n_(.7)                                           # batimento cardíaco (lub-dub)
    x = silence(n)
    for at, f, g in ((0, 55, 1.0), (n_(.2), 48, .7)):
        m = n_(.18)
        place(x, mulv(gain(osc(m, lambda t, ff=f: ff - 20 * t), 1), env_exp(m, .04)), at, g)
    write(d + 'heartbeat.wav', lp(x, .2))


# ==================================================================== AMBIENTES
def build_ambient(rng):
    d = 'ambient/'
    n = n_(10.0)                                         # vento: rajadas + assobio fantasma
    w = lp(noise(n + SR, rng), .03)
    m = [.45 + .35 * math.sin(i / SR * TAU / 5) + .2 * math.sin(i / SR * TAU / 1.7) for i in range(n + SR)]
    whistle = gain(bp(noise(n + SR, rng), 900, 12), .6)
    wm = [max(0, math.sin(i / SR * TAU / 10 + 1)) ** 3 for i in range(n + SR)]
    write(d + 'wind.wav', loopable(add(gain(mulv(w, m), 3.0), mulv(whistle, wm)), SR))
    n = n_(16.0)                                         # mina: drone grave suave + ar parado + zumbido distante
    N = n + SR * 2
    sw = [.6 + .4 * math.sin(i / SR * TAU / 16) for i in range(N)]
    x = add(gain(osc(N, 55), .28), mulv(gain(osc(N, 82.4), .12), sw), gain(osc(N, 110.35), .04),
            gain(smooth_air(N, rng), .22),
            mulv(gain(osc(N, 659.3), .012), [max(0, math.sin(i / SR * TAU / 8)) ** 6 for i in range(N)]))
    write(d + 'mine.wav', loopable(reverb(x, 1.2, .3, 0)[:N], SR * 2), .7)
    n = n_(10.0)                                         # industrial: zumbido elétrico + batidas metálicas longe
    hum = add(gain(osc(n + SR, 50), .25), gain(osc(n + SR, 100), .15), gain(osc(n + SR, 150), .08), gain(osc(n + SR, 200, 'sq'), .01))
    x = add(hum, gain(smooth_air(n + SR, rng), .25))
    for _ in range(5):
        mm = n_(.6)
        place(x, mulv(add(gain(osc(mm, 340 + rng.randint(-40, 40)), .2), gain(osc(mm, 720), .1)), env_exp(mm, .12)), rng.randrange(0, n - SR))
    write(d + 'industrial.wav', loopable(reverb(x, 1.4, .35, 0)[:n + SR], SR))
    n = n_(16.0)                                         # zona funda: sub-drone que pulsa devagar + coro distante
    N = n + SR * 2
    x = add(gain(osc(N, 36.7), .3), gain(osc(N, 37.4), .3), gain(osc(N, 55.1), .08), gain(smooth_air(N, rng, .004), .18))
    voice = add(gain(osc(N, 110, 'saw'), .5), gain(osc(N, 110.6, 'saw'), .5))
    choir = add(gain(bp(voice, 700, 6), 1.0), gain(bp(voice, 1100, 7), .6))
    x = add(x, mulv(gain(norm(choir), .05), [max(0, math.sin(i / SR * TAU / 16 + 1)) ** 3 for i in range(N)]))
    write(d + 'deep.wav', loopable(reverb(lp(x, .2), 1.5, .35, 0)[:N], SR * 2), .7)
    n = n_(1.0)
    x = [0.0] * (n + 2205)
    for i in range(len(x)):
        t = i / SR
        x[i] = (.4 * math.sin(TAU * 50 * t) + .25 * math.sin(TAU * 100 * t) + .15 * math.sin(TAU * 150 * t)) * (.7 + .3 * (1 if (t * 25) % 1 < .3 else 0))
    write(d + 'generator.wav', loopable(add(x, gain(lp(noise(len(x), rng), .1), .3)), 2205))
    n = n_(1.0)
    x = [0.0] * (n + 1102)
    for i in range(len(x)):
        t = i / SR
        ph = (t * 22) % 1
        x[i] = math.exp(-ph * 30) * rng.uniform(-1, 1) * .9 + math.sin(TAU * 90 * t) * .2 * math.exp(-ph * 10)
    write(d + 'drill.wav', loopable(lp(x, .3), 1102))
    n = n_(4.0)                                          # fogo crepitando
    x = gain(lp(noise(n + SR, rng), .08), .5)
    for _ in range(140):
        mm = n_(.015)
        place(x, mulv(hp(noise(mm, rng), .4), env_exp(mm, .003)), rng.randrange(0, n), rng.uniform(.3, 1.0))
    write(d + 'fire.wav', loopable(x, SR))
    n = n_(3.0)
    write(d + 'steam.wav', loopable(gain(hp(noise(n + SR, rng), .5), .5), SR))
    n = n_(2.0)
    x = [0.0] * (n + 2205)
    for i in range(len(x)):
        t = i / SR
        x[i] = .4 * math.sin(TAU * 60 * t) * (.6 + .4 * math.sin(TAU * 1.5 * t)) + .1 * math.sin(TAU * 180 * t)
    write(d + 'pump_hum.wav', loopable(x, 2205))
    n = n_(4.0)                                          # chiado de fita com "vozes" quase audíveis
    x = gain(hp(noise(n + SR, rng), .6), .3)
    for _ in range(3):
        mm = n_(.6)
        place(x, mulv(formant_noise(mm, rng, [(500, 1), (1000, .6)]), env_hann(mm)), rng.randrange(0, n - mm), .5)
    write(d + 'tape_hiss.wav', loopable(x, SR))


# ======================================================================= MÚSICA
NOTE = {'A2': 110.0, 'D3': 146.83, 'E3': 164.81, 'F3': 174.61, 'A3': 220.0, 'D4': 293.66, 'E4': 329.63,
        'F4': 349.23, 'G#4': 415.30, 'A4': 440.0, 'B4': 493.88, 'C5': 523.25, 'D5': 587.33, 'G4': 392.0}
# Lamento em ré "dórico ucraniano" (D E F G# A B C), compasso ternário lento.
MELODY = [('A4', 1), ('D5', 1), ('C5', 1), ('B4', .5), ('A4', .5), ('G#4', 1), ('A4', 2), ('F4', 1), ('E4', .5),
          ('F4', .5), ('G#4', 1), ('A4', 3), ('D4', 1), ('F4', 1), ('A4', 1.5), ('G#4', .5), ('F4', 1), ('E4', 1),
          ('D4', 1), ('E4', 1), ('F4', .5), ('E4', .5), ('D4', 3), (None, 3)]


def bandura(melody, beat, rng, total, start=1.0, bass=True, vel=1.0):
    x = silence(n_(total))
    t = start
    bar = 0.0
    for note, beats in melody:
        if n_(t) >= len(x):
            break
        if note:
            f = NOTE[note]
            place(x, karplus(f, 3.2, rng, .9965, .5), n_(t), .55 * vel)
            if rng.random() < .3:                      # trêmulo de bandura: repete a nota bem baixinho
                place(x, karplus(f, 1.5, rng, .995, .4), n_(t + beat * .25), .18 * vel)
        if bass and bar % 3 == 0:
            root = 'D3' if int(bar / 3) % 4 != 2 else 'A2'
            place(x, karplus(NOTE[root], 4.0, rng, .9975, .3), n_(t), .45 * vel)
        t += beats * beat
        bar += beats
    return x


def build_music(rng):
    d = 'music/'
    beat = .95
    n = n_(48.0)                                         # base: lamento dedilhado + pad de ré
    N = n + SR * 3
    pad = add(gain(osc(N, 73.42), .5), gain(osc(N, 110.0), .25), gain(osc(N, 146.83, 'tri'), .08))
    pad = mulv(pad, [.55 + .45 * math.sin(i / SR * TAU / 24) for i in range(N)])
    mel = bandura(MELODY, beat, rng, N / SR, 1.0)
    mel2 = bandura(MELODY[:12] + [(None, 6)], beat * 1.05, rng, N / SR, 25.0, vel=.8)
    x = add(gain(pad, .18), mel, mel2)
    write(d + 'base.wav', loopable(reverb(lp(x, .35), 1.6, .45, 0)[:N], SR * 3), .75)
    n = n_(40.0)                                         # mina rasa: quinta grave + lembrança da canção, longe
    N = n + SR * 3
    x = add(gain(osc(N, 55), .3), mulv(gain(osc(N, 82.4), .14), [.5 + .5 * math.sin(i / SR * TAU / 20) for i in range(N)]),
            gain(osc(N, 110.4, 'tri'), .04))
    far = bandura([('A4', 2), ('G#4', 1), ('F4', 2), ('E4', 1), ('D4', 6)], 1.4, rng, N / SR, 6.0, bass=False, vel=.5)
    far2 = bandura([('F4', 2), ('E4', 1), ('D4', 3), (None, 2), ('A3', 4)], 1.5, rng, N / SR, 24.0, bass=False, vel=.4)
    x = add(x, gain(lp(add(far, far2), .12), 1.0))
    write(d + 'dread_low.wav', loopable(reverb(x, 1.8, .55, 0)[:N], SR * 3), .7)
    n = n_(36.0)                                         # profundezas: pulso grave lento + quinta diminuta, sem serra
    N = n + SR * 3
    pulse = [.55 + .45 * max(0, math.sin(i / SR * TAU * .42)) ** 6 for i in range(N)]
    x = add(mulv(add(gain(osc(N, 41.2), .5), gain(osc(N, 41.9), .4)), pulse),
            mulv(gain(osc(N, 58.3, 'tri'), .1), [max(0, math.sin(i / SR * TAU / 18)) ** 2 for i in range(N)]),
            gain(smooth_air(N, rng, .003), .12))
    for k in range(3):
        m = n_(6.0)
        sw = mulv(add(gain(osc(m, 233.1), .05), gain(osc(m, 329.6), .04)), [(i / m) ** 3 * (1 - (i / m) ** 8) for i in range(m)])
        place(x, sw, n_(4 + k * 11))
    write(d + 'dread_deep.wav', loopable(reverb(lp(x, .1), 1.7, .5, 0)[:N], SR * 3), .7)


# ================================================================ v0.3: novos sons
def build_v3(rng):
    d = 'sfx/'
    x = silence(n_(2.2))                                 # subiu de nível: arpejo dedilhado + sino
    for k, f in enumerate((293.66, 349.23, 440.0, 587.33)):
        place(x, karplus(f, 2.0, rng, .997, .6), n_(k * .11), .6)
    place(x, mulv(add(gain(osc(n_(1.8), 1174.7), .25), gain(osc(n_(1.8), 1761), .08)), env_ad(n_(1.8), .005, .5)), n_(.44))
    write(d + 'level_up.wav', reverb(x, 1.1, .35, .8), .8)
    x = silence(n_(.9))                                  # bancada: três marteladas + catraca
    for k in range(3):
        m = n_(.25)
        hit = add(mulv(gain(lp(noise(m, rng), .12), 1.2), env_exp(m, .02)),
                  mulv(add(gain(osc(m, 1850 + k * 90), .25), gain(osc(m, 3300), .1)), env_exp(m, .05)))
        place(x, hit, n_(k * .2))
    for k in range(5):
        m = n_(.02)
        place(x, mulv(hp(noise(m, rng), .5), env_exp(m, .003)), n_(.62 + k * .045), .5)
    write(d + 'craft.wav', reverb(x, .6, .2, .3), .8)
    n = n_(.45)                                          # bateria trocada: clique + chiado do capacitor subindo
    x = add(mulv(hp(noise(n, rng), .4), env_exp(n, .006)),
            mulv(gain(osc(n, lambda t: 700 + 3600 * t), .12), [min(1, i / (.05 * SR)) * math.exp(-i / (.2 * SR)) for i in range(n)]))
    write(d + 'battery.wav', x, .7)
    n = n_(.3)                                           # objeto caindo no chão
    write(d + 'thud.wav', add(mulv(gain(lp(noise(n, rng), .06), 1.4), env_exp(n, .03)), mulv(gain(osc(n, 95), .6), env_exp(n, .05))), .7)
    n = n_(1.6)                                          # sinalizador: risco + ignição + chiado
    scratch = mulv(gain(bp(noise(n_(.18), rng), 2500, 1.5), .7), env_hann(n_(.18)))
    hiss = mulv(gain(hp(noise(n, rng), .35), .5),
                [min(1, max(0, i - n_(.15)) / (.08 * SR)) * math.exp(-max(0, i - n_(.15)) / (1.0 * SR)) for i in range(n)])
    x = add(scratch + silence(n - n_(.18)), hiss)
    for _ in range(25):
        m = n_(.01)
        place(x, mulv(hp(noise(m, rng), .5), env_exp(m, .002)), rng.randrange(n_(.2), n - m), rng.uniform(.3, .8))
    write(d + 'flare.wav', x, .7)
    n = n_(2.1)                                          # pavio queimando
    x = mulv(gain(bp(noise(n, rng), 3500, 1.2), .5), [.6 + .4 * rng.random() for _ in range(n)])
    for _ in range(60):
        m = n_(.008)
        place(x, mulv(hp(noise(m, rng), .6), env_exp(m, .002)), rng.randrange(0, n - m), rng.uniform(.4, 1.0))
    write(d + 'fuse.wav', mulv(x, env_hann(n, .3)), .6)
    n = n_(2.6)                                          # explosão subterrânea
    boom = add(mulv(gain(lp(noise(n, rng), .04), 2.5), env_ad(n, .005, .35)),
               mulv(gain(osc(n, lambda t: 55 * math.exp(-t * 1.5) + 24), 1.4), env_ad(n, .003, .6)),
               mulv(gain(hp(noise(n, rng), .3), .5), env_exp(n, .02)))
    for _ in range(14):
        m = n_(.15)
        place(boom, mulv(lp(noise(m, rng), .1), env_exp(m, .04)), rng.randrange(n_(.3), n - m), rng.uniform(.15, .4))
    write(d + 'explosion.wav', reverb(boom, 1.6, .45, 1.5), .95)
    a = 'ambient/'
    n = n_(5.0)                                          # estática de rádio (fora de estação)
    N = n + SR
    x = add(gain(hp(noise(N, rng), .3), .35), gain(bp(noise(N, rng), 1800, .8), .25),
            [.04 * math.sin(TAU * 50 * i / SR) for i in range(N)])
    x = mulv(x, [.75 + .25 * math.sin(i / SR * TAU * .7) * math.sin(i / SR * TAU * 3.1) for i in range(N)])
    for _ in range(40):
        m = n_(.006)
        place(x, mulv(noise(m, rng), env_exp(m, .002)), rng.randrange(0, N - m), rng.uniform(.4, 1.0))
    write(a + 'radio_static.wav', loopable(x, SR), .6)
    n = n_(28.0)                                         # Rádio Kyiv: a mesma canção, em ondas médias
    N = n + SR
    song = bandura(MELODY, .8, rng, N / SR, .5)
    song = bp(add(song, gain(osc(N, 146.83, 'tri'), .04)), 900, .6)
    am = [.7 + .3 * math.sin(i / SR * TAU * .33) for i in range(N)]
    write(a + 'radio_song.wav', loopable(add(mulv(norm(song), am), gain(hp(noise(N, rng), .5), .06)), SR), .6)
    n = n_(10.0)                                         # locutor: fala ininteligível em ondas curtas
    N = n + SR
    voice = silence(N)
    t0 = n_(.1)
    while t0 < N - n_(.4):
        if rng.random() < .12:
            t0 += n_(rng.uniform(.3, .7))
            continue
        m = n_(rng.uniform(.08, .2))
        vowel = rng.choice([[(700, 1.0), (1200, .7)], [(400, 1.0), (2000, .5)], [(550, 1.0), (900, .8)], [(300, 1.0), (2300, .4)]])
        p0 = rng.uniform(110, 150)
        buzz = gain(osc(m, lambda t, p=p0: p + 15 * math.sin(t * 11), 'sq'), .3)
        syl = silence(m)
        for f, g in vowel:
            syl = add(syl, gain(bp(buzz, f, 4), g))
        place(voice, mulv(syl, env_hann(m)), t0)
        t0 += m + n_(rng.uniform(.02, .1))
    write(a + 'radio_speech.wav', loopable(add(bp(norm(voice), 1300, .7), gain(hp(noise(N, rng), .45), .05)), SR), .6)


# ================================================================ v0.5: inimigos e pavor
def build_v5(rng):
    d = 'sfx/'
    for k in range(2):                                   # guincho de rato: chirps FM agudos
        n = n_(.32)
        x = silence(n)
        for c in range(rng.randint(2, 3)):
            m = n_(rng.uniform(.04, .07))
            f0 = rng.uniform(2600, 3600)
            ch = mulv(gain(osc(m, lambda t, f=f0: f + 900 * math.sin(t * 90)), .5), env_hann(m, .7))
            place(x, ch, n_(c * .09 + rng.uniform(0, .02)))
        write(d + 'rat_squeak_%d.wav' % (k + 1), reverb(x, .5, .2, .2), .6)
    n = n_(.45)
    write(d + 'rat_hiss.wav', mulv(gain(bp(noise(n, rng), 4200, 1.5), .7), env_ad(n, .05, .25)), .5)
    n = n_(.2)
    write(d + 'rat_bite.wav', add(mulv(hp(noise(n, rng), .5), env_exp(n, .01)),
                                  mulv(gain(osc(n, lambda t: 3200 - 4000 * t), .3), env_exp(n, .05))), .6)
    n = n_(.5)
    write(d + 'rat_die.wav', mulv(gain(osc(n, lambda t: 3400 * math.exp(-t * 3) + 600), .4), env_ad(n, .01, .2)), .5)

    def voice(n, f0, formants, rough=0.0, glide=None):
        src = gain(osc(n, (lambda t: f0 + glide(t)) if glide else f0, 'saw'), .6)
        if rough:
            src = mulv(src, [1 - rough + rough * (0.5 + 0.5 * math.sin(i / SR * TAU * 27 + rng.random())) for i in range(n)])
        src = add(src, gain(noise(n, rng), .25))
        out = silence(n)
        for f, g in formants:
            out = add(out, gain(bp(src, f, 5), g))
        return out
    n = n_(1.3)                                          # rosnado grave e rouco
    write(d + 'dog_growl.wav', reverb(mulv(lp(voice(n, 85, [(400, 1.0), (900, .4)], rough=.6), .3), env_hann(n, .6)), .7, .2, .4), .7)
    x = silence(n_(.7))                                  # dois latidos secos
    for k in range(2):
        m = n_(.17)
        place(x, mulv(voice(m, 320 - k * 30, [(650, 1.0), (1300, .5)]), env_ad(m, .005, .06)), n_(k * .28))
    write(d + 'dog_bark.wav', reverb(x, .9, .3, .6), .8)
    n = n_(.5)
    write(d + 'dog_bite.wav', add(mulv(gain(lp(noise(n, rng), .3), 1.2), env_exp(n, .02)),
                                  mulv(lp(voice(n, 110, [(450, 1.0)], rough=.5), .3), env_ad(n, .02, .2))), .75)
    n = n_(.4)
    write(d + 'dog_yelp.wav', mulv(voice(n, 700, [(1100, 1.0), (2200, .4)], glide=lambda t: 700 * math.sin(t * 7.8)), env_hann(n, .8)), .6)

    n = n_(1.6)                                          # respiração do Vulto: um único fôlego, lento e grave
    br = mulv(gain(bp(noise(n, rng), 380, 1.4), 1.0), [math.sin(math.pi * i / n) ** 2 for i in range(n)])
    br = add(br, mulv(gain(osc(n, lambda t: 70 - 10 * t), .25), env_hann(n)))
    write(d + 'vulto_breath.wav', reverb(lp(br, .25), 1.4, .55, 1.2), .55)
    n = n_(1.0)                                          # Vulto erguendo os braços: cluster que sobe
    x = silence(n)
    for f in (233, 247, 262, 349):
        place(x, mulv(gain(osc(n, lambda t, ff=f: ff * (1 + .6 * t)), .12), [(i / n) ** 2 for i in range(n)]), 0)
    x = add(x, mulv(gain(hp(noise(n, rng), .4), .3), [(i / n) ** 3 for i in range(n)]))
    write(d + 'vulto_rise.wav', reverb(x, 1.2, .4, .6), .6)
    n = n_(.9)
    x = add(mulv(gain(osc(n, lambda t: 50 - 20 * t), 1.0), env_exp(n, .15)),
            mulv(gain(hp(noise(n, rng), .3), .6), env_exp(n, .05)),
            mulv(gain(osc(n, lambda t: 2900 + 400 * math.sin(t * 40), 'saw'), .08), env_exp(n, .2)))
    write(d + 'vulto_strike.wav', reverb(x, 1.3, .45, 1.0), .85)
    n = n_(.5)
    x = mulv(gain(hp(noise(n, rng), .55), .5), env_hann(n, .5))
    for _ in range(30):
        m = n_(.006)
        place(x, mulv(noise(m, rng), env_exp(m, .002)), rng.randrange(0, n - m), rng.uniform(.4, 1.0))
    write(d + 'vulto_burn.wav', x, .5)
    n = n_(1.6)
    x = add(mulv(formant_noise(n, rng, [(500, 1), (900, .6)]), [(1 - i / n) ** 2 for i in range(n)]),
            mulv(gain(osc(n, lambda t: 90 * math.exp(-t * 1.5) + 30), .5), env_exp(n, .6)))
    write(d + 'vulto_fade.wav', reverb(x, 1.6, .6, 1.5), .6)
    n = n_(.22)
    write(d + 'enemy_hit.wav', add(mulv(gain(lp(noise(n, rng), .12), 1.4), env_exp(n, .03)),
                                   mulv(gain(osc(n, lambda t: 140 - 200 * t), .7), env_exp(n, .04))), .7)
    n = n_(3.6)                                          # trovão: estalo + ronco que rola
    crack = mulv(gain(hp(noise(n_(.25), rng), .2), 1.0), env_exp(n_(.25), .05))
    roll = mulv(gain(lp(lp(noise(n, rng), .03), .05), 6.0), [min(1, i / (.2 * SR)) * math.exp(-i / (1.4 * SR)) * (.7 + .3 * math.sin(i / SR * TAU * 1.3)) for i in range(n)])
    write(d + 'thunder.wav', reverb(add(crack + silence(n - n_(.25)), roll), 1.8, .5, 1.5), .9)
    n = n_(2.2)                                          # grito muito distante (fica a dúvida se foi real)
    sc = voice(n, 520, [(800, 1.0), (1200, .6), (2600, .3)], glide=lambda t: 260 * math.sin(t * 1.4) - 120 * t)
    write(d + 'distant_scream.wav', reverb(lp(mulv(sc, env_hann(n, 1.5)), .08), 2.0, .75, 2.5), .45)
    n = n_(1.6)                                          # arranhões dentro da parede
    x = silence(n)
    t0 = 0
    while t0 < n - n_(.1):
        m = n_(rng.uniform(.04, .09))
        place(x, mulv(gain(bp(noise(m, rng), rng.uniform(1800, 3200), 3), .8), env_hann(m)), t0)
        t0 += m + n_(rng.uniform(.02, .12))
    write(d + 'wall_scratch.wav', reverb(lp(x, .5), .8, .35, .6), .5)
    a = 'ambient/'
    n = n_(8.0)                                          # camada de pavor (perseguição): cluster grave + agudo fino
    N = n + SR
    pulse = [.6 + .4 * max(0, math.sin(i / SR * TAU * 1.1)) ** 4 for i in range(N)]
    x = add(mulv(add(gain(osc(N, 55), .3), gain(osc(N, 77.8), .22), gain(osc(N, 58.3), .18)), pulse),
            mulv(gain(osc(N, lambda t: 2200 + 300 * math.sin(t * .8)), .02), [.5 + .5 * math.sin(i / SR * TAU / 4) for i in range(N)]),
            gain(smooth_air(N, rng, .01), .1))
    write(a + 'dread_near.wav', loopable(reverb(lp(x, .3), 1.3, .35, 0)[:N], SR), .7)


if __name__ == '__main__':
    rng = random.Random(1986)
    build_sfx(rng)
    build_ambient(rng)
    build_music(rng)
    build_v3(rng)
    build_v5(rng)
    print('Áudio gerado em', OUT)
