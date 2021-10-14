#!/usr/bin/bash


git clone --bare https://github.com/geblanco/dot_files.git $HOME/.cfg

function config {
   /usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME $@
}

function backup {
  local bb=$1; shift;
  local is_dir=$(echo $bb | tr "/" "\n" | wc -l)
  if [[ $is_dir -gt 1 ]]; then
   local bdir=$(dirname $bb)
   local bfile=$(basename $bb)
   echo "create .config-backup/$bdir"
   mkdir --parents .config-backup/$bdir
   #echo "move $bb .config-backup/$bdir/$bfile"
   mv $bb .config-backup/$bdir/$bfile
  else
   #echo "mv $bb .config-backup/$bb"
   mv $bb .config-backup/$bb
  fi
}

mkdir -p .config-backup
config checkout desktop
if [ $? = 0 ]; then
  echo "Checked out config.";
else
    echo "Backing up pre-existing dot files.";
    #config checkout 2>&1 | egrep "\s+\." | awk {'print $1'} | xargs -I{} mv {} .config-backup/{}
    config checkout desktop 2>&1 | egrep "\s+\." | awk {'print $1'} >> .config-backup/to_back.txt
    backup_files=$(sort .config-backup/to_back.txt | uniq)
    #echo $backup_files > .config-backup/to_back.txt
    for file in $backup_files; do
	  echo "backup $file"
	  backup $file
    done
fi;
config checkout desktop
config config status.showUntrackedFiles no
