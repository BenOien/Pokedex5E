from pathlib import Path
import json
import re
import requests
from codecs import open
input_path = Path(r"D:\Repo\Pokedex\assets\datafiles\trainer_classes_list.json")
output_path = Path(r"trainer_classes.json")

dirty_reg = re.compile('title="(\d{3})"><img alt="\d{3}"')

new_json = {}


def clean_content(content):
    pre_removed = content.split('id="Trainer_list">Trainer list', 1)[-1]
    post_removed = pre_removed.split('''mon Stadium</span></h3>''')[0]
    return post_removed


def main():
    with open(input_path, "r+", "utf-8") as f:
        data = json.load(f)
        for trainer in data["Classes"]:
            raw_url = "https://m.bulbapedia.bulbagarden.net/wiki/{}_(Trainer_class)".format(trainer.replace(" ", "_"))
            print(trainer)

            new_json[trainer] = []
            r = requests.get(raw_url)
            for m in re.findall(dirty_reg, clean_content(str(r.content))):
                new_json[trainer].append(m)

        with open(output_path, "w") as fp:
            json.dump(new_json, fp, ensure_ascii=False)

main()
