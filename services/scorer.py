def calculate_scores(test_results):
    """
    Convert PASS/FAIL results into scores out of 100.
    Each test has a weight contributing to the overall score.
    """

    scores = {}

    # Individual test scores
    scores['self_healing'] = 95 if test_results.get('pod_chaos') == 'PASS' else 30
    scores['cpu_resilience'] = 88 if test_results.get('cpu_stress') == 'PASS' else 25
    scores['memory_resilience'] = 90 if test_results.get('memory_stress') == 'PASS' else 25
    scores['network_resilience'] = 92 if test_results.get('network_delay') == 'PASS' else 20
    scores['packet_resilience'] = 89 if test_results.get('packet_loss') == 'PASS' else 20
    scores['recovery'] = 95 if test_results.get('recovery_validation') == 'PASS' else 10

    # Weighted overall score
    weights = {
        'self_healing': 0.25,
        'cpu_resilience': 0.15,
        'memory_resilience': 0.15,
        'network_resilience': 0.15,
        'packet_resilience': 0.15,
        'recovery': 0.15
    }

    overall = sum(
        scores[key] * weights[key]
        for key in weights
    )

    scores['overall'] = round(overall)

    # Grade
    if scores['overall'] >= 90:
        scores['grade'] = 'A'
        scores['grade_label'] = 'Excellent'
        scores['grade_color'] = '#00ff88'
    elif scores['overall'] >= 75:
        scores['grade'] = 'B'
        scores['grade_label'] = 'Good'
        scores['grade_color'] = '#88ff00'
    elif scores['overall'] >= 60:
        scores['grade'] = 'C'
        scores['grade_label'] = 'Average'
        scores['grade_color'] = '#ffaa00'
    else:
        scores['grade'] = 'D'
        scores['grade_label'] = 'Poor'
        scores['grade_color'] = '#ff4444'

    return scores
