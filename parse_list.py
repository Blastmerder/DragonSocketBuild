import hashlib
import json
import os
import zipfile
import requests
import tomllib  # Для Python 3.11+. Если у вас Python < 3.11, используйте: pip install tomli as tomllib


def calculate_sha1(file_path: str) -> str:
    """Вычисляет SHA1-хэш файла."""
    sha1 = hashlib.sha1()
    with open(file_path, "rb") as f:
        while chunk := f.read(8192):
            sha1.update(chunk)
    return sha1.hexdigest()


def get_local_mod_data(file_path: str, filename: str) -> tuple[str, str]:
    """Локально читает JAR манифест, возвращая (имя_мода, внутренний_id)."""
    try:
        with zipfile.ZipFile(file_path, "r") as archive:
            file_list = archive.namelist()
            if "fabric.mod.json" in file_list:
                with archive.open("fabric.mod.json") as f:
                    data = json.loads(f.read().decode("utf-8", "ignore"))
                    return data.get("name", filename), data.get("id", "")
            elif "quilt.mod.json" in file_list:
                with archive.open("quilt.mod.json") as f:
                    data = json.loads(f.read().decode("utf-8", "ignore"))
                    ql = data.get("quilt_loader", {})
                    return (
                        ql.get("metadata", {}).get("name", filename),
                        ql.get("id", ""),
                    )
            elif "META-INF/mods.toml" in file_list:
                with archive.open("META-INF/mods.toml") as f:
                    toml_data = tomllib.loads(
                        f.read().decode("utf-8", "ignore")
                    )
                    mods_list = toml_data.get("mods", [])
                    if mods_list and isinstance(mods_list, list):
                        mod = mods_list[0]
                        return mod.get("displayName", filename), mod.get(
                            "modId", ""
                        )
    except Exception:
        pass
    return filename, ""


def parse_mods_for_wget(mods_dir_path: str) -> list[dict[str, str]]:
    result = []
    hashes_map = {}

    if not os.path.exists(mods_dir_path):
        print(f"Ошибка: Директория {mods_dir_path} не найдена.")
        return result

    # Шаг 1: Собираем хэши и локальные данные
    for filename in os.listdir(mods_dir_path):
        if not (
            filename.endswith(".jar") or filename.endswith(".jar.disabled")
        ):
            continue

        file_path = os.path.join(mods_dir_path, filename)
        try:
            file_hash = calculate_sha1(file_path)
            local_name, local_id = get_local_mod_data(file_path, filename)
            hashes_map[file_hash] = {
                "filename": filename,
                "path": file_path,
                "local_name": local_name,
                "local_id": local_id,
            }
        except Exception:
            continue

    if not hashes_map:
        return result

    # Шаг 2: Отправляем запрос к v2/version_files (правильный эндпоинт для поиска версий)
    payload = {"hashes": list(hashes_map.keys()), "algorithm": "sha1"}
    headers = {
        "User-Agent": "MyMinecraftWgetExporter/2.0.0 (contact@example.com)"
    }

    api_data = {}
    try:
        # Используем POST /v2/version_files для массового получения метаданных по хэшам
        response = requests.post(
            "https://api.modrinth.com/v2/version_files",
            json=payload,
            headers=headers,
        )
        if response.status_code == 200:
            api_data = response.json()
        else:
            print(
                f"[Система] Основной API вернул {response.status_code}. Переключаемся на резервный поиск."
            )
    except Exception as e:
        print(f"[Система] Ошибка сети: {e}")

    # Шаг 3: Сопоставляем данные
    for file_hash, local_meta in hashes_map.items():
        filename = local_meta["filename"]
        file_path = local_meta["path"]
        mod_name = local_meta["local_name"]
        mod_id = local_meta["local_id"]

        download_url = ""
        side = "both"

        # Вариант А: Мод успешно найден в Modrinth по хэшу
        if file_hash in api_data and api_data[file_hash] is not None:
            version_info = api_data[file_hash]

            # Получаем сторону мода
            client = version_info.get("client_side", "both")
            server = version_info.get("server_side", "both")
            if client == "required" and server == "unsupported":
                side = "client"
            elif server == "required" and client == "unsupported":
                side = "server"
            else:
                side = "both"

            # Вытаскиваем прямую ссылку
            files = version_info.get("files", [])
            for f_entry in files:
                if f_entry.get("primary") or f_entry.get("hashes", {}).get(
                    "sha1"
                ) == file_hash:
                    download_url = f_entry.get("url", "")
                    break
            if not download_url and files:
                download_url = files[0].get("url", "")

        # Вариант Б: Хэш не совпал (как у Xaero с CurseForge), пробуем найти проект по внутреннему ID
        elif mod_id:
            try:
                # Спрашиваем инфо о самом проекте на Modrinth по его ID (например, "xaeroworldmap")
                proj_res = requests.get(
                    f"https://modrinth.com{mod_id}",
                    headers=headers,
                )
                if proj_res.status_code == 200:
                    proj_info = proj_res.json()
                    mod_name = proj_info.get("title", mod_name)

                    # Определяем сторону из метаданных проекта
                    c_side = proj_info.get("client_side", "")
                    s_side = proj_info.get("server_side", "")
                    if c_side == "required" and s_side == "unsupported":
                        side = "client"
                    elif s_side == "required" and c_side == "unsupported":
                        side = "server"

                    # Ссылку на конкретный файл по ID проекта получить пакетно нельзя (нужна конкретная версия),
                    # но мы хотя бы точно узнали его сторону (side) для экспорта!
            except Exception:
                pass

        # Формируем словарь
        result.append(
            {
                "modName": mod_name,
                "side": side,
                "downloadUrl": download_url,
            }
        )

    return result


# === ЗАПУСК ===
if __name__ == "__main__":
    PATH_TO_MODS = (
        r"/home/blastmerder/games/PrismLauncher-Linux-Qt6-Portable-11.0.2-1/instances/1.21.1(2)/minecraft/mods"
    )

    mods_data = parse_mods_for_wget(PATH_TO_MODS)

    # 1. Выводим весь массив в консоль для проверки
    print(json.dumps(mods_data, ensure_ascii=False, indent=2))

    # 2. Генерируем список ТОЛЬКО для сервера (wget -i server_urls.txt)
    # Исключаем моды, у которых side == "client"
    with open("server_urls.txt", "w", encoding="utf-8") as f_server:
        for mod in mods_data:
            if mod["side"] in ["server", "both"] and mod["downloadUrl"]:
                f_server.write(mod["downloadUrl"] + "\n")

    # 3. Дополнительно: выводим список модов, которые были отфильтрованы (пропущены)
    print("\n" + "=" * 40)
    print("[Инфо] Следующие клиентские моды были исключены из списка:")
    for mod in mods_data:
        if mod["side"] == "client":
            print(f" ->  [{mod['side'].upper()}] {mod['modName']}")

    print("=" * 40)
    print(
        f"[Успешно] Файл 'server_urls.txt' создан. Чисто клиентские моды успешно отфильтрованы!"
    )
