This folder is intended to contain external CR files that you supplied separately. On the machine
where you package the chart you can copy your uploaded CRs into these files so Helm includes them
in the chart package.


Place your local uploaded files (from your environment) here before packaging the chart:


- files/strimzi-kraft-nodepools.yaml <-- copy from: /mnt/data/strimzi-kraft-nodepools.yaml
- files/topics.yaml <-- copy from: /mnt/data/topics.yaml
- files/user.yaml <-- copy from: /mnt/data/user.yaml


Example copy commands (run on the machine that will run 'helm package'):


mkdir -p kafka/files
cp /mnt/data/strimzi-kraft-nodepools.yaml kafka/files/strimzi-kraft-nodepools.yaml
cp /mnt/data/topics.yaml kafka/files/topics.yaml
cp /mnt/data/user.yaml kafka/files/user.yaml


Notes:
- The Chart uses .Files.Get to embed the contents of these files directly into the rendered templates.
- If you prefer not to embed, you can apply those CRs separately using kubectl apply -f /mnt/data/...