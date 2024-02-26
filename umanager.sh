#!/bin/bash
# Script Name: uname
# Description: simplified user and group management, for more information refer to the manual
# Author: Lukasz Walczak
# Date: 2023-6-11
# Version: 1.0
<<LICENSE
MIT License

Copyright (c) 2023 Lukasz Walczak

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
LICENSE
#variables used to break appropriate while loops
#if EXIT equals 1 the program will end
EXIT=0
EXITEDITUSERMENU=0
EXITEDITGROUPMENU=0
SELECTEDUSER=""
SELECTEDGROUP=""
VERSION="1.0"
#variables used to signalize if group/user exist
#if USEREXISTS equals 1, selected user exists, 0 if it does not
USEREXISTS=0
GROUPEXISTS=0


#beggining of functions section
#in this section all necessary functions are defined
#checks if user stored in $SELECTEDUSER variable exists
function checkIfUserExists(){
  if id "$SELECTEDUSER" > /dev/null 2>&1; then 
    USEREXISTS=1
  else
    USEREXISTS=0
  fi
}

#checks if group stored in $SELECTEDGROUP variable exists
function checkIfGroupExists(){
  if getent group "$SELECTEDGROUP" | grep -q "^$SELECTEDGROUP:"; then
      GROUPEXISTS=1
  else
      GROUPEXISTS=0 
  fi
}

#checks if provided group name is a valid group's name and if so
#stores it in $SELECTEDGROUP variable
#if $GROUPEXISTS equals 0 that means $SELECTEDGROUP variable is na valid group name
function selectGroup(){
  read -p "Enter user name you wish to select: " SELECTEDGROUP
  checkIfGroupExists
  if [ $GROUPEXISTS -eq 1 ]; then
    echo "Group selected succesfully"
  else
    SELECTEDGROUP=""
    echo "Group does not exist"
  fi

}

#checks if provided username is a valid user's name and if so
#stores it in $SELECTEDUSER variable
#if $USEREXISTS equals 0 that means $SELECTEDUSER is not a valid user to modify
function selectUser(){
  read -p "Enter user name you wish to select: " SELECTEDUSER
  checkIfUserExists
  if [ $USEREXISTS -eq 1 ]; then
    echo "User selected succesfully"
  else
    SELECTEDUSER=""
    echo "User does not exist"
  fi
}

#lists all available users
function listUsers(){
  clear
  awk -F: '{print NR ". " $1}' /etc/shadow
}

#lists all available groups
function listGroups(){
  clear
  awk -F: '{ printf "%d. %s\n", NR, $1 }' /etc/group
}

#adds a new user, firstly checking if there is not a user that uses same username
function addUser(){
  clear
  NEWUSERNAME=""
  read -p "Enter new username: " NEWUSERNAME
  TEMPUSER=$SELECTEDUSER
  SELECTEDUSER=$NEWUSERNAME
  checkIfUserExists
  SELECTEDUSER=$TEMPUSER
  if [ $USEREXISTS -eq 1 ]; then
    echo "user already exists"
    return 0
  fi
  adduser $NEWUSERNAME
  echo "User $NEWUSERNAME created"
}

#adds a new group, firstly checking if there is not a group that uses same group name
function addGroup(){
  clear
  NEWGROUPNAME=""
  read -p "Enter new group name: " NEWGROUPNAME
  TEMPGROUP=$SELECTEDGROUP
  SELECTEDGROUP=$NEWGROUPNAME
  checkIfGroupExists
  SELECTEDGROUP=$TEMPGROUP
  if [ $GROUPEXISTS -eq 1 ]; then
    echo "Group already exists"
    return 0
  fi
  groupadd $NEWGROUPNAME
  echo "User $NEWGROUPNAME created"
}

#if there is a selected user that is valid removes this user
#it does not remove any of the users file
#home directory is left untouched
function removeUser(){
  clear
  if [ $USEREXISTS -eq 0 ]; then
    echo "Select user you wish to remove first"
    return 0
  fi
  CHOICE='n'
  read -p "Do you really want to delete: $SELECTEDUSER ? y\n" CHOICE
  if [ "$CHOICE" != "y"  ] && [ "$CHOICE" != "Y" ]; then
    return 0
  fi
  userdel $SELECTEDUSER
  echo "Deleted user $SELECTEDUSER"
  USEREXISTS=0
  SELECTEDUSER=""
}

#if there is a valid group selected removes that group
function removeGroup(){
  clear
  if [ $GROUPEXISTS -eq 0 ]; then
    echo "Select group you wish to remove first"
    return 0
  fi
  CHOICE='n'
  read -p "Do you really want to delete: $SELECTEDGROUP ? y\n" CHOICE
  if [ "$CHOICE" != "y"  ] && [ "$CHOICE" != "Y" ]; then
    return 0
  fi
  groupdel $SELECTEDGROUP
  echo "Deleted user $SELECTEDGROUP"
  GROUPEXISTS=0
  SELECTEDGROUP=""
}

#edits user comment in /etc/shadow
function editUserComment(){
  clear
  NEWUSERCOMMENT=""
  read -p "Enter new user comment: " NEWUSERCOMMENT
  usermod -c "$NEWUSERCOMMENT" "$SELECTEDUSER"
}

#changes user home directory
function changeUserHomeDir(){
  clear
  eval echo "current $SELECTEDUSER home directory: ~test"
  CHOICE='n'
  read -p "Do you really want to change $SELECTEDUSER home directory?: y\n" CHOICE
  if [ "$CHOICE" != "y"  ] && [ "$CHOICE" != "Y" ]; then
    return 0
  fi
  NEWHOMEDIRPATH=""
  read -p "Enter full path for new home directory" NEWHOMEDIRPATH
  if ! [[ -d "$NEWHOMEDIRPATH" ]]; then
    echo "Directory does not exist."
    return 0
  fi
  usermod -d $NEWHOMEDIRPATH $SELECTEDUSER
}

#changes user expiration date, after that date users account is disabled
function changeUserExpireDate(){
  clear
  chage -l $SELECTEDUSER | head -n 4 | tail -n 1
  CHOICE='n'
  read -p "Do you really want to change $SELECTEDUSER expire date?: y\n" CHOICE
  if [ "$CHOICE" != "y"  ] && [ "$CHOICE" != "Y" ]; then
    return 0
  fi
  EXPIREYEAR=""
  EXPIREMONTH=""
  EXPIREDAY=""
  read -p "Enter year of expiration" EXPIREYEAR
  read -p "Enter month of expiration" EXPIREMONTH
  read -p "Enter day of expiration" EXPIREDAY
  if ! date -d "$EXPIREYEAR-$EXPIREMONTH-$EXPIREDAY" >/dev/null 2>&1; then
    echo "Invalid date."
    return 0
  fi
  usermod -e "$EXPIREYEAR-$EXPIREMONTH-$EXPIREDAY"
}

#unlocks user by removing "!" in front of the encrypted password
function unlockUser(){
  usermod -U $SELECTEDUSER
}

#locks user account from loggin in by putting "!" in front of the encrypted password
function lockUser(){
  usermod -L $SELECTEDUSER
}

#changes user password expire date
#after that date after logging in user must change his password
function changeUserPasswordExpire(){
  clear
  chage -l $SELECTEDUSER | head -n 2 | tail -n 1
  CHOICE='n'
  read -p "Do you really want to change $SELECTEDUSER password expire date?: y\n" CHOICE
  if [ "$CHOICE" != "y"  ] && [ "$CHOICE" != "Y" ]; then
    return 0
  fi
  EXPIREDAYS=""
  read -p "Enter day of expiration" EXPIREDAYS
  if ! [[ "$EXPIREDAYS" =~ ^[1-9][0-9]*$ ]]; then
    echo "Invalid number of days"
    return 0
  fi
  usermod -f $EXPIREDAYS
}

#if there are no collisions with other users' logins, changes user's login
function changeUserLogin(){
  clear
  echo "Current user login $SELECTEDUSER"
  CHOICE='n'
  read -p "Do you really want to change $SELECTEDUSER login?: y\n" CHOICE
  if [ "$CHOICE" != "y"  ] && [ "$CHOICE" != "Y" ]; then
    return 0
  fi
  NEWUSERLOGIN=""
  read -p "Enter new login: " NEWUSERLOGIN
  usermod -l $NEWUSERLOGIN $SELECTEDUSER
  SELECTEDUSET=$NEWUSERLOGIN
}

#changes user password
function changeUserPassword(){
  clear
  CHOICE='n'
  read -p "Do you really want to change $SELECTEDUSER password?: y\n" CHOICE
  if [ "$CHOICE" != "y"  ] && [ "$CHOICE" != "Y" ]; then
    return 0
  fi
  passwd $SELECTEDUSER
}

#if there is a valid group to add to, appends group's list and adds user to it
function addUserToGroup(){
  clear
  listGroups
  GROUPTOADD=""
  read -p "Write group name you wish to add user to: " GROUPTOADD
  TEMPGROUP=$SELECTEDGROUP
  SELECTEDGROUP=$GROUPTOADD
  checkIfGroupExists
  if [ $GROUPEXISTS -eq 0 ]; then
    echo "Group does not exist"
  fi
  SELECTEDGROUP=$TEMPGROUP
  usermod -aG $GROUPTOADD $SELECTEDUSER
}

#lists groups that $SELECTEDUSER is in
function listUserGroups(){
  clear
  groups $SELECTEDUSER
}

#removes user from group $REMOVEFROMGROUP
function removeUserFromGroup(){
  clear
  listUserGroups
  REMOVEFROMGROUP=""
  read -p "Enter group name you want to remove user from" REMOVEFROMGROUP
  TEMPGROUP=$SELECTEDGROUP
  SELECTEDGROUP=$REMOVEFROMGROUP
  checkIfGroupExists
  if [ $GROUPEXISTS -eq 0 ];then
    echo "Group does not exist"
  fi
  SELECTEDGROUP=$TEMPGROUP
  if ! id -nG $SELECTEDUSER | grep -qw "<groupname>"; then
    echo "User is not a member of the $REMOVEFROMGROUP group"
    return 0
  fi
  gpasswd --delete $SELECTEDUSER $REMOVEFROMGROUP
}

#changes user shell to one of the avilable ones in /etc/shells
function changeUserShell(){
  clear
  echo "current $SELECTEDUSER shell: $(grep "^$SELECTEDUSER:" /etc/passwd | awk -F: '{print $NF}')"
  CHOICE='n'
  read -p "Do you really want to change $SELECTEDUSER shell?: y\n" CHOICE
  if [ "$CHOICE" != "y"  ] && [ "$CHOICE" != "Y" ]; then
    return 0
  fi
  echo "Avilable shells:"
  cat /etc/shells
  CHOSENSHELL=""
  read -p "Enter shell you want to change to" $CHOSENSHELL
  if ! grep -Fxq "$CHOSENSHELL" /etc/shells; then
    echo "Chosen shell is not valid and available."
    return 0
  fi 
  usermod -s "$CHOSENSHELL" $SELECTEDUSER
}

#menu for editing user
function editUserMenu(){
  if [ $USEREXISTS -eq 0 ]; then
    echo "Select user you wish to edit first"
    return 0
  fi
  CHOICE=""
  echo "Edit user $SELECTEDUSER"
  echo "1. Edit user comment"
  echo "2. Change user home directory"
  echo "3. Change expire date"
  echo "4. Lock user"
  echo "5. Unlock user"
  echo "6. Change password expire date"
  echo "7. Change login"
  echo "8. Change user password"
  echo "9. Add user to a group"
  echo "10. Remove user from group"
  echo "11. List user groups"
  echo "12. Change users shell"
  echo "13. Edit user disk quota"
  echo "14. Jail in ftp"
  echo "15. Exit"
  read -p "Enter 1-15 to chose option: " CHOICE
  case "$CHOICE" in
    1) editUserComment
    ;;
    2) changeUserHomeDir
    ;;
    3) changeUserExpireDate
    ;;
    4) lockUser
    ;;
    5) unlockUser
    ;;
    6) changeUserPasswordExpire
    ;;
    7) changeUserLogin
    ;;
    8) changeUserPassword
    ;;
    9) addUserToGroup
    ;;
    10) removeUserFromGroup
    ;;
    11) listUserGroups
    ;;
    12) changeUserShell
    ;;
    13) editUserDiskQuota
    ;;
    14) jailFTP
    ;;
    15)clear 
      EXITEDITUSERMENU=1
    ;;
    *)
    ;;
  esac
}

#checks if 1st argument provided to the function is a valid non negative integer
function isNonNegativeInt() {
  [[ $1 =~ ^[0-9]+$ ]]
}

#checks if provided GID is unique and no other group has the same
is_gid_unique() {
  while IFS=: read -r _ _ gid _; do
    if [[ $gid == "$1" ]]; then
      return 1
    fi
  done < /etc/group
  return 0
}

#changes GID of the group selected
function changeGID(){
  clear
  getent group $SELECTEDGROUP | awk -F: '{print "Group GID: " $3}'
  CHOICE='n'
  read -p "Do you really want to change $SELECTEDGROUP GID?: y\n" CHOICE
  if [ "$CHOICE" != "y"  ] && [ "$CHOICE" != "Y" ]; then
    return 0
  fi
  NEWGID=""
  read -p "Enter new GID" NEWGID
  if ! is_non_negative_decimal_integer "$NEWGID"; then
    echo "Invalid GID. GID must be a non-negative decimal integer."
    return 0
  elif ! is_gid_unique "$NEWGID"; then
    echo "Invalid GID. GID is not unique."
    return 0
  fi
  groupmod -g "$NEWGID" $SELECTEDGROUP
}

#changes group name also updating users' group membership
function changeGroupName(){
  clear
  CHOICE='n'
  read -p "Do you really want to change $SELECTEDGROUP name?: y\n" CHOICE
  if [ "$CHOICE" != "y"  ] && [ "$CHOICE" != "Y" ]; then
    return 0
  fi
  NEWGROUPNAME=""
  read -p "Enter new group name: " NEWGROUPNAME 
  TEMPGROUP=$SELECTEDGROUP
  SELECTEDGROUP=$NEWGROUPNAME
  checkIfGroupExists
  if [ $GROUPEXISTS -eq 1 ];then
    echo "Group with that name already exists"
    SELECTEDGROUP=$TEMPGROUP
    return 0
  fi
  groupmod -n "$NEWGROUPNAME" "$TEMPGROUP"
}

#menu for editing groups
function editGroupMenu(){
  if [ $GROUPEXISTS -eq 0 ]; then
    echo "Select group you wish to edit first"
    return 0
  fi
  CHOICE=""
  echo "Edit group $SELECTEDGROUP"
  echo "1. Change GID"
  echo "2. Change name"
  echo "3. Exit"
  read -p "Enter 1-3 to chose option: " CHOICE
  case "$CHOICE" in
    1) changeGID
    ;;
    2) changeGroupName
    ;;
    3)clear 
      EXITEDITGROUPMENU=1
    ;;
    *)
    ;;
  esac
}

#loop for editing groups
function editGroup(){
  while [ $EXITEDITGROUPMENU -eq 0 ]; do
    editGroupMenu
  done
}

#loop for editing users
function editUser(){
  while [ $EXITEDITUSERMENU -eq 0 ]; do
    editUserMenu
  done
}

#main menu
function menu(){
  CHOICE=""
  echo "MENU"
  if [ $USEREXISTS -eq 1 ]; then
    echo "Currently selected user: $SELECTEDUSER"
  fi
  if [ $GROUPEXISTS -eq 1 ]; then
    echo "Currently selected group: $SELECTEDGROUP"
  fi
  echo "1. List all users"
  echo "2. List all groups"
  echo "3. Add new user"
  echo "4. Add new group"
  echo "5. Remove existing user"
  echo "6. Remove existing group"
  echo "7. Edit selected user"
  echo "8. Edit selected group"
  echo "9. Select user"
  echo "10. Select group"
  echo "11. exit"
  read -p "Enter 1-11 to choose option " CHOICE
  case "$CHOICE" in
    1) listUsers
    ;;
    2) listGroups
    ;;
    3) addUser
    ;;
    4) addGroup
    ;;
    5) removeUser
    ;;
    6) removeGroup
    ;;
    7) editUser
      EXITEDITUSERMENU=0
    ;;
    8) editGroup
    ;;
    9) selectUser
    ;;
    10) selectGroup
    ;;
    11)clear 
      EXIT=1
    ;;
    *)
    ;;
  esac

}
#
#end of functions section
#handling of flags provided
# -v version of the script
# -h opens manual for the script
while getopts "vh" flag
  do
    case "${flag}" in
        h) man umanager
          exit 0
        ;;
        v) echo "Version $VERSION"
          exit 0
        ;;
        *)
        ;;
    esac
done
if [[ -z "$SUDO_USER" ]]; then
  echo "This script must be run with sudo or as a root to work correctly"
  exit 1
fi
#main loop of the script
while [ $EXIT -eq 0 ]; do
  menu   
done

