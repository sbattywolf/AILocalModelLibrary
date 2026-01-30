from services.comm.dialog_manager import DialogManager


def main():
    dm = DialogManager()
    res = dm.select_option(["Start task", "Defer task", "Cancel"], timeout_seconds=15)
    print("Selection:", res)


if __name__ == "__main__":
    main()
