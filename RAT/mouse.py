import pyautogui
import random
import time
import argparse

parser = argparse.ArgumentParser(
    description="Déplace la souris vers une position aléatoire à intervalles réguliers."
)
parser.add_argument(
    "duree",
    type=float,
    help="Durée totale d'exécution en secondes"
)
parser.add_argument(
    "delai",
    type=float,
    help="Délai entre deux déplacements en secondes"
)

args = parser.parse_args()

largeur, hauteur = pyautogui.size()

fin = time.time() + args.duree

while time.time() < fin:
    x = random.randint(0, largeur - 1)
    y = random.randint(0, hauteur - 1)

    pyautogui.moveTo(x, y, duration=0)
    print(f"Déplacement vers ({x}, {y})")

    temps_restant = fin - time.time()
    if temps_restant > 0:
        time.sleep(min(args.delai, temps_restant))