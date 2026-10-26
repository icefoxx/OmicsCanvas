"""Scientific invariants for linked tree/embedding preparation and error handling."""
import csv
import json
import shutil
import subprocess
from pathlib import Path

import pytest
from plot_web.server.runner import plugin_env

ROOT = Path(__file__).resolve().parents[2]
PLUGIN = ROOT / 'plugins/circular_tree_embedding'
pytestmark = pytest.mark.skipif(not shutil.which('Rscript'), reason='Rscript required')
TABLE = '''cell_id,UMAP_1,UMAP_2,class,subclass,subtype,Gene_A,Gene_B
c1,-10,1,Neuronal,Excitatory,A,0,0
c2,-9,2,Neuronal,Excitatory,A,0,0
c3,10,1,Neuronal,Inhibitory,B,0.1,0.2
c4,9,2,Neuronal,Inhibitory,B,0.1,0.2
c5,-9,1,Glial,Astroglia,C,10,10
c6,-10,2,Glial,Astroglia,C,10,10
'''


def render(folder, table=TABLE, **params):
    folder.mkdir(exist_ok=True)
    (folder/'input.csv').write_text(table)
    (folder/'params.json').write_text(json.dumps(dict(width=5, height=5, dpi=72, label_show=False, **params)))
    result = subprocess.run(['Rscript', str(PLUGIN/'plot.R'), '--input', str(folder/'input.csv'), '--params', str(folder/'params.json'), '--output', str(folder/'out')], cwd=ROOT, env=plugin_env(), capture_output=True, text=True, timeout=90)
    return result, folder/'out'


def read_csv(path):
    with path.open() as handle:
        return list(csv.DictReader(handle))


def test_annotation_colors_match_and_embedding_is_scaled_isotropically(tmp_path):
    result, out = render(tmp_path, group_column='class', group_colors={'class:Neuronal':'#123456'})
    assert result.returncode == 0, result.stdout + result.stderr
    figure = json.loads((out/'figure.json').read_text())
    assert figure['tree']['mode'] == 'annotation'
    assert figure['tree']['distance'] is None
    points = read_csv(out/'data_used.csv')
    assert {p['plot_color'] for p in points if p['class']=='Neuronal'} == {'#123456'}
    assert figure['colors']['class']['Neuronal'] == '#123456'
    x_scale = (float(points[2]['plot_x'])-float(points[0]['plot_x']))/20
    y_scale = (float(points[1]['plot_y'])-float(points[0]['plot_y']))
    assert x_scale == pytest.approx(y_scale)
    assert all((out/f'result.{ext}').stat().st_size>100 for ext in ['svg','png','pdf'])


def test_similarity_uses_features_not_embedding_neighbors(tmp_path):
    result, out = render(tmp_path, tree_mode='similarity', feature_columns=['Gene_A','Gene_B'], scale_features=False)
    assert result.returncode == 0, result.stdout + result.stderr
    edges = read_csv(out/'tree_edges_used.csv')
    first_children = {e['child'] for e in edges if e['parent']=='merge:1'}
    assert first_children == {'leaf:A','leaf:B'}
    assert len(read_csv(out/'profiles_used.csv')) == 3
    assert json.loads((out/'figure.json').read_text())['tree']['distance'] == 'euclidean'


@pytest.mark.parametrize('params,table,message', [
    ({}, TABLE.replace('Glial,Astroglia,C','Glial,Astroglia,A'), 'unique hierarchy path'),
    ({'tree_mode':'similarity','feature_columns':['UMAP_1','Gene_A']}, TABLE, 'embedding coordinates'),
    ({'tree_mode':'similarity','feature_columns':['Gene_A','Gene_B']}, TABLE.replace('10,10','NA,10'), 'missing or nonnumeric'),
])
def test_invalid_data_fail_with_actionable_errors_and_remove_stale_figures(tmp_path, params, table, message):
    (tmp_path/'out').mkdir()
    (tmp_path/'out/result.png').write_bytes(b'stale preview')
    result, out = render(tmp_path, table, **params)
    assert result.returncode != 0
    assert message in json.loads((out/'error.json').read_text())['detail']
    assert not list(out.glob('result.*'))
