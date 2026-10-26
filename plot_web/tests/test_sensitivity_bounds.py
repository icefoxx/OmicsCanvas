from scripts.param_sensitivity import perturb


def test_probability_and_angle_perturbations_respect_editor_bounds():
    assert 0.5 <= perturb('confidence_level', {'type':'number','min':.5,'max':.999}, .95) < 1
    assert -180 <= perturb('rotation', {'type':'number','min':-180,'max':180}, 170) <= 180
    assert perturb('opacity', {'type':'number','min':0,'max':1}, 0) == 1


def test_bounded_integer_perturbation_changes_value_without_leaving_range():
    value = perturb('bins', {'type':'integer','min':2,'max':5}, 5)
    assert isinstance(value, int) and 2 <= value < 5
    assert perturb('fixed', {'type':'integer','min':1,'max':1}, 1) is None


def test_normalization_preserves_numeric_constraints_for_the_editor_and_scanner():
    from plot_web.schema_normalize import normalize_params_schema
    normalized = normalize_params_schema({'statistics': {
        'confidence': {'type':'number','default':.95,'minimum':.5,'maximum':.999,'multipleOf':.001},
        'bins': {'type':'integer','default':5,'min':2,'max':5,'step':1}}})
    confidence = normalized['statistics']['confidence']
    assert (confidence['min'], confidence['max'], confidence['step']) == (.5,.999,.001)
    assert perturb('confidence', confidence, .95) < 1
    assert normalized['statistics']['bins']['type'] == 'integer'
