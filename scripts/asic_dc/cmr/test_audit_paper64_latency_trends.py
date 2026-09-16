from audit_paper64_latency_trends import audit_curve


def test_monotonic_curve_has_no_decrease():
    rows = [{"load": str(x), "latency": str(y)} for x, y in ((5, 1), (10, 2), (20, 3))]
    result = audit_curve(rows, "load", "latency")
    assert result["adjacent_decreases"] == 0
    assert result["spearman_rho"] == 1.0
    assert result["soft_anomaly"] is False


def test_single_small_dip_is_reported_but_not_failed():
    rows = [{"load": str(x), "latency": str(y)} for x, y in ((5, 1), (10, 2), (20, 1.95), (40, 3))]
    result = audit_curve(rows, "load", "latency")
    assert result["adjacent_decreases"] == 1
    assert result["maximum_decrease_percent"] < 5.0
    assert result["soft_anomaly"] is False


def test_large_or_repeated_drop_sets_soft_anomaly():
    rows = [{"load": str(x), "latency": str(y)} for x, y in ((5, 10), (10, 9), (20, 8))]
    result = audit_curve(rows, "load", "latency")
    assert result["maximum_consecutive_decreases"] == 2
    assert result["soft_anomaly"] is True
