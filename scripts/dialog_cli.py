#!/usr/bin/env python3
"""Small CLI wrapper to prompt a human using DialogManager."""
from services.comm.dialog_manager import DialogManager


def main():
    dm = DialogManager(default_human_origin=True)
    options = ["Do thing A", "Do thing B", "Cancel"]
    res = dm.select_option(options, timeout_seconds=30)
    print("Selected:", res)


if __name__ == "__main__":
    main()
