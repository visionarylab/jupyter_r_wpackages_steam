
https://oneuptime.com/blog/post/2026-01-25-github-codespaces-configuration/view

https://rocker-project.org/images/devcontainer/features.html




Why r-rig wins here: Deepnote's default R environment (deepnote/ir_with_libs) targets user-space persistence. It directs package maps to ~/work/.R/library so they persist through cloud power cycles. rig handles R system dependencies and seamlessly works alongside user-level installation tools like pak to grab fast binaries without breaking Deepnote's underlying storage map

## Deepnote
In the default R environments
You can simply use the install.packages and library commands the way you normally would.

R packages often take a long time to install. We install them to your work folder by setting your environment variable R_LIBS_USER="~/work/.R/library", so they stay there during hardware restarts.


https://microsoft.github.io/code-with-engineering-playbook/CI-CD/recipes/reusing-devcontainers-within-a-pipeline/


https://github.com/deepnote/environments/blob/main/ir/ir-with-libs/Dockerfile.ir

https://github.com/orgs/community/discussions/58399

https://opensource.posit.co/blog/2025-05-19_quarto-codespaces/



"ghcr.io/rocker-org/devcontainer-features/r-rig:1": {


ghcr.io/rocker-org/devcontainer-features/renv-cache:latest

https://github.com/eitsupi/arf/blob/fb891c10c9579b12f3eca41595eabe4a8dcfbe7c/.devcontainer/devcontainer.json#L4


https://github.com/tjanevic/correlated-data/blob/d28f0b164642eefc18392cb9690f72ffac9e1a06/.devcontainer/devcontainer.json#L4

https://github.com/rocker-org/devcontainer-try-r/blob/main/.devcontainer/template-r2u/devcontainer.json

https://github.com/zq2323/devcontainer-templates/blob/9f90b59bf0ed97dde1ffc048e0ae98a5734dc5b5/src/r-ver/NOTES.md?plain=1#L46


https://github.com/conradborchers/srl-cycles-lak24/blob/5960f3c8a6e1cd87a3b63a3aba171e31050ec887/.devcontainer/devcontainer.json#L13

https://github.com/pharmaverse/admiralonco/blob/423126c4c86efc625d711570e682a012159a56e5/.devcontainer/4.2/devcontainer.json#L19

https://github.com/pmags/Health-Policy-Impact-causalInferece/blob/daa5694cb8690ba948b9c8c73a7110ce4c5f27d1/.devcontainer/devcontainer.json#L7


https://github.com/MiguelRodo/Prac23RodoTutu/blob/5e303a6b1eac0185cf602a7a0451ba1073f76036/.devcontainer/devcontainer.json#L8
https://github.com/pharmaverse/sdtm.oak/blob/6b5d887aa560c77b3ec983071489725e3046ce1e/.devcontainer/devcontainer.json#L21


