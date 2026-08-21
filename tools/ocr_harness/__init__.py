"""The recognition measurement loop.

Four pieces, in the order they are used:

    reading.py   the model - one normalised Reading, parsed out of ChordPro text
    metrics.py   what a Reading scores against a hand-verified gold Reading
    engines.py   the adapters that produce a Reading from a photograph
    report.py    the run-against-baseline table, and what counts as a regression

Why the model is ChordPro text rather than a nested structure: the gold answer
has to be checkable by eye against the photograph, and correcting it has to be
editing a line. A monospaced chord row makes a chord's character column its
position, which is what makes placement machine-checkable from plain text - the
same trick tools/fixtures/score.py uses for the generated pages.
"""
