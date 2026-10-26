"""Small numerical reference cases for added scientific plot renderers."""
import csv
import json
from pathlib import Path
import shutil
import subprocess
import pytest
from plot_web.server.runner import plugin_env

ROOT = Path(__file__).resolve().parents[2]
pytestmark = pytest.mark.skipif(not shutil.which('Rscript'), reason='Rscript required')


def render(tmp_path, plugin, table, **params):
    tmp_path.mkdir(parents=True, exist_ok=True)
    (tmp_path/'input.csv').write_text(table)
    (tmp_path/'params.json').write_text(json.dumps(dict(width=5, height=4, dpi=72, **params)))
    out = tmp_path/'out'
    proc = subprocess.run(['Rscript', str(ROOT/'plugins'/plugin/'plot.R'), '--input', str(tmp_path/'input.csv'), '--params', str(tmp_path/'params.json'), '--output', str(out)], cwd=ROOT, env=plugin_env(), capture_output=True, text=True, timeout=90)
    return proc, out


def rows(out, name='data_used.csv'):
    with (out/name).open() as f:
        return list(csv.DictReader(f))


def success(result):
    proc, out = result
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert all((out/f'result.{ext}').stat().st_size > 100 for ext in ['png', 'svg', 'pdf'])
    return out


def test_kaplan_meier_censoring_reference(tmp_path):
    out = success(render(tmp_path, 'survival_plot', 'time,event,group\n1,1,A\n2,0,A\n3,1,A\n4,0,A\n', stat_method='none'))
    data = rows(out)
    by_time = {float(r['time']): r for r in data}
    assert float(by_time[1]['survival']) == pytest.approx(.75)
    assert float(by_time[3]['survival']) == pytest.approx(.375)


def test_binary_tied_scores_auc_and_average_precision(tmp_path):
    table = 'score,outcome\n0.8,1\n0.8,0\n0.4,1\n0.2,0\n'
    out = success(render(tmp_path/'roc', 'binary_evaluation_plot', table))
    performance = json.loads((out/'figure.json').read_text())['statistics']['performance']
    if isinstance(performance, list):
        performance = performance[0]
    assert performance['auc'] == pytest.approx(.625)
    assert performance['average_precision'] == pytest.approx(7/12, abs=.0001)
    out = success(render(tmp_path/'cal', 'binary_evaluation_plot', table, plot_type='calibration'))
    performance = json.loads((out/'figure.json').read_text())['statistics']['performance']
    if isinstance(performance, list):
        performance = performance[0]
    assert performance['brier_score'] == pytest.approx(.27)


def test_bland_altman_signed_differences(tmp_path):
    out = success(render(tmp_path, 'bland_altman_plot', 'method_a,method_b\n10,8\n12,11\n14,15\n'))
    stat = json.loads((out/'figure.json').read_text())['statistics']
    assert stat['bias'] == pytest.approx(2/3, abs=.0001)
    assert stat['sd'] == pytest.approx((7/3)**.5, abs=.0001)


def test_ecdf_preserves_tied_probability_mass(tmp_path):
    out = success(render(tmp_path, 'ecdf_plot', 'value\n1\n1\n2\n', stat_method='none'))
    data = rows(out)
    assert any(float(r['x']) == 1 and float(r['y']) == pytest.approx(2/3) for r in data)
    assert float(data[-1]['y']) == 1


def test_oncoprint_multihit_counts_samples_once(tmp_path):
    out = success(render(tmp_path, 'oncoprint_plot', 'gene,sample,alteration\nG1,S1,Missense\nG1,S1,Deletion\nG1,S2,None\n'))
    assert float(rows(out, 'gene_frequencies_used.csv')[0]['fraction']) == .5


def test_alignment_consensus_uses_all_sequences_in_denominator(tmp_path):
    out = success(render(tmp_path, 'sequence_alignment_plot', 'sequence_id,sequence\nS1,AC\nS2,AT\nS3,-T\n'))
    assert [float(r['fraction']) for r in rows(out, 'consensus_used.csv')] == pytest.approx([2/3, 2/3])


@pytest.mark.parametrize('plugin,table,params', [
    ('spatial_region_plot', 'x,y,region,value\n0,0,A,1\n1,0,A,2\n0,1,A,1\n', {}),
    ('sequence_alignment_plot', 'sequence_id,sequence\nA,AC\nB,ACT\n', {}),
    ('forest_plot', 'label,estimate,lower,upper\nA,2,3,4\n', {}),
    ('line_plot', 'x,y,lower,upper\n1,2,3,4\n', {'band_show': True}),
])
def test_invalid_scientific_inputs_clear_stale_exports(tmp_path, plugin, table, params):
    (tmp_path/'out').mkdir()
    (tmp_path/'out/result.png').write_bytes(b'stale')
    proc, out = render(tmp_path, plugin, table, **params)
    assert proc.returncode != 0
    assert (out/'error.json').is_file()
    assert not list(out.glob('result.*'))


def test_invalid_survival_run_clears_old_auxiliary_tables(tmp_path):
    (tmp_path/'out').mkdir()
    (tmp_path/'out/risk_table_used.csv').write_text('old,risk\n1,10\n')
    proc, out = render(tmp_path, 'survival_plot', 'time,event\n-1,1\n2,0\n', stat_method='none')
    assert proc.returncode != 0
    assert not (out/'risk_table_used.csv').exists()
