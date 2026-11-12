from roboflow import Roboflow

rf = Roboflow(api_key="WVye4Z150Tg3doLH85Cr")
project = rf.workspace("bird-classifications").project("bird-classifications")

dataset = project.version(2).download(
    model_format="folder",
    location="./bird-classifications-v2",
)

print("Dataset descargado en:", dataset.location)