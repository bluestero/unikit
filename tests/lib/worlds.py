"""Ready-made paths the case files share (a layer's own worlds are in its tests/lib)."""
import os

from fixture import REPO

FK = os.path.join(REPO, "bin/fk")
FK_LAYER = os.path.join(REPO, "layers/bluefeels")   # the look layer the fk tests use
