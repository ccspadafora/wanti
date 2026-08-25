"""Infer and validate technical specs for catalog vehicle versions."""

from __future__ import annotations

import re

from apps.catalog.models import VehicleVersion, VehicleVersionSpec
from apps.common.exceptions import ValidationError

FUEL_OPTIONS = ('Gasolina', 'Diésel', 'Eléctrico', 'Híbrido')
TRANSMISSION_OPTIONS = ('Mecánica', 'Automática', 'Semi-automática')
TRACTION_OPTIONS = ('4x4', '4x2', 'AWD')
BODY_OPTIONS = ('Hatchback', 'Sedán', 'Pick-up', 'SUV', 'Coupé', 'Van', 'Camioneta')

_ATTR_MAP = {
    'fuel_type': ('fuel_types', FUEL_OPTIONS),
    'transmission': ('transmissions', TRANSMISSION_OPTIONS),
    'traction': ('tractions', TRACTION_OPTIONS),
    'body_type': ('body_types', BODY_OPTIONS),
}


def infer_specs_from_name(name: str) -> dict:
    """Heuristic parse of version label → allowed option lists + optional engine_cc."""
    raw = (name or '').strip()
    lower = raw.lower()
    if not raw or 'otra' in lower or 'no sé' in lower or 'no se' in lower:
        return {
            'fuel_types': [],
            'transmissions': [],
            'tractions': [],
            'body_types': [],
            'engine_cc': None,
        }

    fuels: list[str] = []
    if re.search(r'\b(tdi|cdi|dci|hdi|bluehdi|crdi|tdci|diesel|di[eé]sel)\b', lower):
        fuels.append('Diésel')
    if re.search(r'\b(ev|bev|el[eé]ctric|e-tron|electric)\b', lower):
        fuels.append('Eléctrico')
    if re.search(r'\b(phev|hev|hybrid|h[ií]brido|mhev)\b', lower):
        fuels.append('Híbrido')
    if re.search(r'\b(tfsi|tsi|gti|mpi|gdi|gasolina|petrol|flex)\b', lower):
        fuels.append('Gasolina')
    # Deduce from numeric displacement tokens like 1.4 / 2.0 when no fuel keyword
    if not fuels and re.search(r'\b\d\.\d\b', lower):
        fuels.append('Gasolina')

    transmissions: list[str] = []
    if re.search(r'\b(at|a/t|auto|autom[aá]tic|cvt|dct|dsg|tiptronic)\b', lower):
        transmissions.append('Automática')
    if re.search(r'\b(mt|m/t|manual|mec[aá]nic)\b', lower):
        transmissions.append('Mecánica')
    if re.search(r'\b(semi.?auto|amt)\b', lower):
        transmissions.append('Semi-automática')

    tractions: list[str] = []
    if re.search(r'\b(awd|4matic|quattro|xdrive|4motion)\b', lower):
        tractions.append('AWD')
    if re.search(r'\b(4x4|4wd)\b', lower):
        tractions.append('4x4')
    if re.search(r'\b(4x2|2wd|fwd|rwd)\b', lower):
        tractions.append('4x2')

    bodies: list[str] = []
    if re.search(r'\bsuv\b|sportback|crossover', lower):
        bodies.append('SUV')
    if re.search(r'\bsed[aá]n\b|\bsedan\b', lower):
        bodies.append('Sedán')
    if re.search(r'\bhatch\b|sportback', lower) and 'SUV' not in bodies:
        bodies.append('Hatchback')
    if re.search(r'\bpick.?up\b|\branger\b', lower):
        bodies.append('Pick-up')
    if re.search(r'\bcoup[eé]\b', lower):
        bodies.append('Coupé')
    if re.search(r'\bvan\b|\bminivan\b', lower):
        bodies.append('Van')
    if re.search(r'\bcamioneta\b', lower):
        bodies.append('Camioneta')

    engine_cc = None
    m = re.search(r'\b(\d{3,4})\s*cc\b', lower)
    if m:
        engine_cc = int(m.group(1))
    else:
        m = re.search(r'\b([1-6]\.\d)\b', lower)
        if m:
            engine_cc = int(round(float(m.group(1)) * 1000))

    def uniq(seq):
        seen = set()
        out = []
        for x in seq:
            if x not in seen:
                seen.add(x)
                out.append(x)
        return out

    return {
        'fuel_types': uniq(fuels),
        'transmissions': uniq(transmissions),
        'tractions': uniq(tractions),
        'body_types': uniq(bodies),
        'engine_cc': engine_cc,
    }


def specs_payload(version: VehicleVersion) -> dict:
    """Resolved specs for API: stored row if present, else live inference."""
    inferred = infer_specs_from_name(version.name)
    stored = None
    try:
        stored = version.specs
    except VehicleVersionSpec.DoesNotExist:
        stored = None

    if stored is not None:
        data = {
            'fuel_types': list(stored.fuel_types or []) or inferred['fuel_types'],
            'transmissions': list(stored.transmissions or []) or inferred['transmissions'],
            'tractions': list(stored.tractions or []) or inferred['tractions'],
            'body_types': list(stored.body_types or []) or inferred['body_types'],
            'engine_cc': stored.engine_cc if stored.engine_cc is not None else inferred['engine_cc'],
            'source': stored.source or 'inferred',
        }
    else:
        data = {**inferred, 'source': 'inferred'}

    locked = {
        'fuel_type': len(data['fuel_types']) == 1,
        'transmission': len(data['transmissions']) == 1,
        'traction': len(data['tractions']) == 1,
        'body_type': len(data['body_types']) == 1,
        'engine_cc': data['engine_cc'] is not None,
    }

    defaults = {
        'fuel_type': data['fuel_types'][0] if locked['fuel_type'] else None,
        'transmission': data['transmissions'][0] if locked['transmission'] else None,
        'traction': data['tractions'][0] if locked['traction'] else None,
        'body_type': data['body_types'][0] if locked['body_type'] else None,
        'engine_cc': data['engine_cc'] if locked['engine_cc'] else None,
    }

    return {
        'version_id': str(version.id),
        'version_name': version.name,
        'allowed': {
            'fuel_type': data['fuel_types'],
            'transmission': data['transmissions'],
            'traction': data['tractions'],
            'body_type': data['body_types'],
            'engine_cc': data['engine_cc'],
        },
        'locked': locked,
        'defaults': defaults,
        'source': data['source'],
    }


def upsert_inferred_spec(version: VehicleVersion) -> VehicleVersionSpec:
    inferred = infer_specs_from_name(version.name)
    obj, _ = VehicleVersionSpec.objects.update_or_create(
        version=version,
        defaults={
            **inferred,
            'source': 'inferred',
        },
    )
    return obj


def validate_detail_against_version(version_id, detail: dict) -> None:
    """Raise ValidationError if detail attrs contradict catalog version specs."""
    if not version_id:
        return
    try:
        version = VehicleVersion.objects.select_related('specs').get(pk=version_id, is_active=True)
    except VehicleVersion.DoesNotExist as exc:
        raise ValidationError('Versión de catálogo no encontrada') from exc

    payload = specs_payload(version)
    allowed = payload['allowed']

    for attr, (allowed_key, _) in _ATTR_MAP.items():
        value = detail.get(attr)
        if value is None or value == '':
            continue
        options = allowed.get(attr) or []
        if options and str(value) not in options:
            raise ValidationError(
                f'{attr}="{value}" no es válido para la versión {version.name}. '
                f'Opciones: {", ".join(options)}'
            )

    engine = detail.get('engine_cc')
    ref = allowed.get('engine_cc')
    if engine is not None and ref is not None:
        try:
            if abs(int(engine) - int(ref)) > 200:
                raise ValidationError(
                    f'engine_cc={engine} no coincide con la referencia de catálogo ({ref} cc)'
                )
        except (TypeError, ValueError):
            pass
