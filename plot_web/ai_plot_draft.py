"""Deterministic, schema-bound plot drafts shared by AI recommendations and rendering.

A draft records intent; it never estimates a model or changes the observation set.
"""
from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

from plot_web.schema_normalize import normalize_params_schema

PLUGIN_DIR = Path(__file__).resolve().parent.parent / 'plugins'


def schema_fields(plugin_id: str) -> dict[str, dict]:
    path = PLUGIN_DIR / plugin_id / 'params_schema.json'
    normalized = normalize_params_schema(json.loads(path.read_text())) or {}
    return {key: field for section in normalized.values() if isinstance(section, dict)
            for key, field in section.items() if isinstance(field, dict)}


def intent_params(plugin_id: str, goal: str) -> dict[str, Any]:
    text = goal.lower()
    # Negated alternatives must not select a mode (e.g. "calibration, do not draw ROC").
    text = re.sub(r"(?:do not|don't|不要|不画)\s*(?:draw\s+|plot\s+)?(?:roc|calibration|precision.recall|decision curve)\b", '', text)
    if plugin_id == 'binary_evaluation_plot':
        modes = {'calibration': r'calibration|校准', 'precision_recall': r'precision[\s_-]*(?:and[\s_-]*)?recall|\bpr curve\b',
                 'decision_curve': r'decision curve|\bdca\b|决策曲线', 'roc': r'\broc\b|receiver operating'}
        found = [mode for mode, pattern in modes.items() if re.search(pattern, text)]
        if len(found) > 1:
            raise ValueError('Choose one diagnostic view per figure: ROC, precision–recall, calibration or decision curve.')
        return {'plot_type': found[0]} if found else {}
    result = {}
    if plugin_id == 'survival_plot':
        if re.search(r'event probability|1\s*[-−]\s*km|事件概率', text):
            result['curve_type'] = 'event_probability'
        elif re.search(r'survival|kaplan|生存', text):
            result['curve_type'] = 'survival'
    if plugin_id == 'forest_plot' and re.search(r'logarithmic|log10|log axis|log scale', text):
        result['x_scale'] = 'log10'
    if plugin_id == 'spatial_region_plot' and re.search(r'\bspots?\b|空间点', text):
        result['map_mark'] = 'spot'
    if plugin_id == 'annotated_tree_plot' and re.search(r'circular|radial|环形', text):
        result['layout'] = 'circular'
    if plugin_id == 'sequence_alignment_plot' and re.search(r'protein|amino acid|蛋白', text):
        result['alphabet'] = 'protein'
    if plugin_id == 'circular_genomic_plot':
        if re.search(r'\blinear\b|线性', text):
            result['layout'] = 'linear'
        for value in ('point', 'bar', 'heatmap'):
            if re.search(r'\b' + value + r'(?:s| tracks?)?\b', text):
                result['track_type'] = value
                break
    return result


ALIASES = {
    'time_column': ['time', 'followup_months', 'follow_up', 'followup', 'duration', 'survival_time', 'os_time'],
    'event_column': ['event', 'event_status', 'status', 'death', 'os_event'],
    'group_column': ['group', 'cohort', 'condition', 'cluster', 'cell_type', 'model'],
    'x_column': ['x', 'PC1', 'UMAP_1', 'UMAP1', 'dim1', 'tsne_1'],
    'y_column': ['y', 'PC2', 'UMAP_2', 'UMAP2', 'dim2', 'tsne_2'],
    'z_column': ['z', 'PC3', 'UMAP_3', 'UMAP3', 'dim3'],
    'outcome_column': ['outcome', 'observed', 'event', 'event_status', 'label'],
    'score_column': ['score', 'probability', 'predicted_probability', 'prediction', 'risk_score'],
    'value_column': ['value', 'expression', 'score'],
    'lower_column': ['lower', 'lwr', 'ci_low'], 'upper_column': ['upper', 'upr', 'ci_high'],
}
ROLE_NAMES = {'time_column': ['time', 'follow-up time'], 'event_column': ['event', 'event indicator'],
              'group_column': ['group', 'cohort'], 'outcome_column': ['outcome', 'observed event'],
              'score_column': ['score', 'predicted probability'], 'x_column': ['x'], 'y_column': ['y'],
              'z_column': ['z'], 'value_column': ['value']}


def complete_params(plugin_id: str, profile: dict, params: dict, goal: str = '') -> dict:
    fields = schema_fields(plugin_id)
    columns = profile.get('columns') or []
    by_lower = {str(c).lower(): c for c in columns}
    result = dict(params)
    for key, field in fields.items():
        if field.get('type') != 'column':
            continue
        roles = ROLE_NAMES.get(key, [key.removesuffix('_column').replace('_', ' ')])
        explicit = None
        for role in roles:
            # Match real header names first, including headers containing spaces.
            for col in columns:
                if re.search(r'[`"\']?' + re.escape(col) + r'[`"\']?\s+(?:as|for|作为|用作)\s+(?:the\s+)?' + re.escape(role) + r'\b', goal, re.I):
                    explicit = col
            assignment = re.search(r'\b' + re.escape(key) + r'\s*[:=]\s*[`"\']?([\w. -]+?)[`"\']?(?:[,;]|$)', goal, re.I)
            if assignment:
                candidate = assignment.group(1).strip()
                if candidate.lower() not in by_lower:
                    raise ValueError(f'{key}: column {candidate!r} was not found. Available columns: {", ".join(columns)}.')
                explicit = by_lower[candidate.lower()]
        if explicit:
            result[key] = explicit
            continue
        if result.get(key) in columns:
            continue
        candidates = [field.get('default'), *ALIASES.get(key, [])]
        match = next((by_lower[str(c).lower()] for c in candidates if c and str(c).lower() in by_lower), None)
        if match:
            result[key] = match
    required_roles = {
        'survival_plot': ('time_column', 'event_column'),
        'binary_evaluation_plot': ('outcome_column', 'score_column'),
        'interactive_3d_scatter': ('x_column', 'y_column', 'z_column'),
    }
    roles = required_roles.get(plugin_id, ())
    if plugin_id == 'binary_evaluation_plot' and result.get('input_mode') == 'curve':
        roles = ('x_column', 'y_column')
    for key in roles:
        if result.get(key, fields.get(key, {}).get('default')) not in columns:
            raise ValueError(f'{key}: map a column before rendering. Available columns: {", ".join(columns)}. Use {key}=your_column in the goal or map it in the editor.')
    result.update(intent_params(plugin_id, goal))
    return result


def draft_summary(plugin_id: str, profile: dict, params: dict) -> dict:
    fields = schema_fields(plugin_id)
    return {'data_scope': 'all_rows', 'rows': profile.get('row_count_estimate'),
            'mode': params.get('plot_type') or params.get('curve_type') or params.get('layout') or 'default',
            'mappings': {key: value for key, value in params.items()
                         if fields.get(key, {}).get('type') in ('column', 'columns')},
            'params': params}


def chat_draft(context: dict, message: str, plugin_id: str | None = None) -> dict | None:
    """Prepare supported edits for review; never claim they have already run."""
    recommendations = context.get('recommendations') or []
    if not recommendations:
        return {'reply': 'Upload a table and choose Recommend only first. I can then explain its workflow or prepare a color edit.', 'engine': 'rules'}
    allowed = {r['plugin_id'] for r in recommendations}
    plugin = plugin_id if plugin_id in allowed else recommendations[0]['plugin_id']
    lines = []
    if re.search(r'\bskill|workflow|工作流|技能', message, re.I):
        names = [s.get('name') or s['skill_id'] for s in context.get('skills', []) if s.get('role') == 'plot_workflow']
        lines.append('Matched plotting workflow: ' + (', '.join(names) if names else 'the selected plot input contract') + '. The renderer uses a schema-bound draft and scientific validation.')
    if re.search(r'all\s+(?:\d+\s+)?(?:rows|observations)|full data|全量|全部', message, re.I):
        lines.append('Uploaded-data rendering now uses all observations. No statistical subsampling is applied.')
    color_names = {'blue': '#0072B2', 'orange': '#E69F00', 'green': '#009E73', 'red': '#D55E00', 'purple': '#CC79A7', 'black': '#000000'}
    tokens = re.findall(r'#[0-9a-fA-F]{6}\b|\b(?:blue|orange|green|red|purple|black)\b', message, re.I)
    colors = [color_names.get(token.lower(), token.upper()) for token in tokens]
    patch = intent_params(plugin, message)
    if colors:
        from plot_web.table_io import read_table_as_dicts
        fields = schema_fields(plugin)
        if 'group_colors' not in fields:
            lines.append('This plot does not expose named group colors; use its color controls in the editor.')
        else:
            _, rows, _ = read_table_as_dicts(Path(context['file']), max_rows=None)
            params = complete_params(plugin, context.get('profile') or {}, {}, context.get('goal') or '')
            column = params.get('group_column')
            if not column:
                lines.append('Map a group column before assigning named group colors.')
            else:
                levels = sorted({str(row[column]) for row in rows if row.get(column) not in (None, '')})
                if len(colors) == 1:
                    colors *= len(levels)
                if len(colors) != len(levels):
                    lines.append(f'There are {len(levels)} groups: {", ".join(levels)}. Specify one color for all groups or one color per group.')
                else:
                    patch['group_colors'] = dict(zip(levels, colors))
                    lines.append('Prepared group colors: ' + ', '.join(f'{level} = {color}' for level, color in patch['group_colors'].items()) + '.')
    if patch:
        lines.append('Review the proposed edit, then select Apply & render. No figure has been changed yet.')
        return {'reply': '\n'.join(lines), 'engine': 'rules', 'render_action': {'plugin_id': plugin, 'params': patch}}
    if lines:
        return {'reply': '\n'.join(lines), 'engine': 'rules'}
    return None
