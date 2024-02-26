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
EXITEDITUSERINFORMATIONMENU=0
SELECTEDUSER=""
SELECTEDGROUP=""
VERSION="1.0"
SHAREDREADONLYDIRECTORY="/home/sharedFtpReadOnly"
SHAREDREADWRITEDIRECTORY="/home/sharedFtpReadWrite"
SHAREDREADONLYGROUP="sharedFtpReadOnly"
SHAREDREADWRITEGROUP="sharedFtpReadWrite"
CHROOTLISTPATH="/etc/vsftpd/chroot_list"
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
    clear
    echo "Group $SELECTEDGROUP selected succesfully"
  else
    clear
    echo "Group $SELECTEDGROUP does not exist"
    SELECTEDGROUP=""
  fi

}

#checks if provided username is a valid user's name and if so
#stores it in $SELECTEDUSER variable
#if $USEREXISTS equals 0 that means $SELECTEDUSER is not a valid user to modify
function selectUser(){
  read -p "Enter user name you wish to select: " SELECTEDUSER
  checkIfUserExists
  if [ $USEREXISTS -eq 1 ]; then
    clear
    echo "User $SELECTEDUSER selected succesfully"
  else
    clear
    echo "User $SELECTEDUSER does not exist"
    SELECTEDUSER=""
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
  mkhomedir_helper $NEWUSERNAME
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
  read -p "Do you really want to delete: $SELECTEDUSER ? [N\y] " CHOICE
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
  read -p "Do you really want to delete: $SELECTEDGROUP ? [N\y] " CHOICE
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
  read -p "Do you really want to change $SELECTEDUSER home directory?: [N\y] " CHOICE
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
  read -p "Do you really want to change $SELECTEDUSER expire date?: [N\y]" CHOICE
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
  read -p "Do you really want to change $SELECTEDUSER password expire date?: [N\y]" CHOICE
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
  read -p "Do you really want to change $SELECTEDUSER login?: [N\y]" CHOICE
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
  read -p "Do you really want to change $SELECTEDUSER password?: [N\y]" CHOICE
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
  read -p "Do you really want to change $SELECTEDUSER shell?: [N\y]" CHOICE
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

#funciton that jails/frees users
#             IMPORTANT
#it does not work without restarting the service
function jailFTP(){
  ISJAILED=""
  if grep -q "^$SELECTEDUSER$" /etc/vsftpd/chroot_list; then
    ISJAILED=1
  else
    ISJAILED=0
  fi
  CHOICE=""
  if [ $ISJAILED -eq 1 ];then
    read -p "Do you want to free $SELECTEDUSER?: [N\y] " CHOICE
    if [ "$CHOICE" != "y" ] && [ "$CHOICE" != "Y" ];then
      return 0
    fi
    sed -i "/^$SELECTEDUSER$/d" "/etc/vsftpd/chroot_list"
  else
    read -p "Do you want to jail $SELECTEDUSER [N\y] " CHOICE
    if [ "$CHOICE" != "y" ] && [ "$CHOICE" != "Y" ];then
      return 0
    fi
    echo "$SELECTEDUSER" >> "/etc/vsftpd/chroot_list"
  fi
}

#converts user shell to /bin/false so user cannot log in on with physical access but he can still
#log in through ftp
function makeUserFTPOnly(){
  clear
  CHOICE='n'
  read -p "Do you want to make $SELECTEDUSER ftp only user? [N\y] " CHOICE
  if [ "$CHOICE" != "y"  ] && [ "$CHOICE" != "Y" ]; then
    return 0
  fi
  usermod -s "/bin/false" "$SELECTEDUSER"
  echo "From now on $SELECTEDUSER can only log in through FTP"
}

function makeUserNotFTPOnly(){
  clear
  CHOICE='n'
  read -p "Do you want to make $SELECTEDUSER a normal user? [N\y] " CHOICE
  if [ "$CHOICE" != "y"  ] && [ "$CHOICE" != "Y" ]; then
    return 0
  fi
  usermod -s "/bin/bash" "$SELECTEDUSER"
  echo "From now on $SELECTEDUSER can log in normally"
}

#defines user home directory as a shared directory where users only have read permission
function makeUserReadOnlySharedDir(){
  CHOICE='n'
  read -p "Do you want to make $SELECTEDUSER a read only user with access read-only access to shared directory? [N\y] " CHOICE
  if [ "$CHOICE" != "y"  ] && [ "$CHOICE" != "Y" ]; then
    return 0
  fi
  if ! grep -q "^$SELECTEDUSER$" /etc/vsftpd/chroot_list; then
    echo "$SELECTEDUSER" >> "/etc/vsftpd/chroot_list"
  fi
  usermod -g "$SHAREDREADONLYGROUP" "$SELECTEDUSER"
  usermod -d "$SHAREDREADONLYDIRECTORY" "$SELECTEDUSER"
}

#defines user home driectory as a shared directory where this user can read and write files
function makeUserReadWriteSharedDir(){
  CHOICE='n'
  read -p "Do you want to make $SELECTEDUSER a read only user with access read-write access to shared directory? [N\y] " CHOICE
  if [ "$CHOICE" != "y"  ] && [ "$CHOICE" != "Y" ]; then
    return 0
  fi
  if ! grep -q "^$SELECTEDUSER$" /etc/vsftpd/chroot_list; then
    echo "$SELECTEDUSER" >> "/etc/vsftpd/chroot_list"
  fi
  usermod -g "$SHAREDREADWRITEGROUP" "$SELECTEDUSER"
  usermod -d "$SHAREDREADWRITEDIRECTORY" "$SELECTEDUSER"
}

#removes the effect of the two functions above
#removes user from both $SHAREDREADONLYGROUP and $SHAREDREADWRITEGROUP
function removeUserFromSharedDirectories(){
  CHOICE='n'
  read -p "Do you want to give back $SELECTEDUSER his home directory and make him a normal user? [N\y] " CHOICE
  if [ "$CHOICE" != "y"  ] && [ "$CHOICE" != "Y" ]; then
    return 0
  fi
  if grep -q "^$SELECTEDUSER$" /etc/vsftpd/chroot_list; then
    sed -i "/^$SELECTEDUSER$/d" "/etc/vsftpd/chroot_list"
  fi
  usermod -g "$SELECTEDUSER" "$SELECTEDUSER"
  chown -R "$SELECTEDUSER:$SELECTEDUSER" "/home/$SELECTEDUSER"
  usermod -d "/home/$SELECTEDUSER" "$SELECTEDUSER"
}

function editUserPhone(){
  clear
  VALIDPHONE=0
  read -p "Enter new $SELECTEDUSER phone number: " NEWPHONENUMBER
  chfn -h "$NEWPHONENUMBER" "$SELECTEDUSER"
}
function editUserWorkPhone(){
  clear
  read -p "Enter new $SELECTEDUSER work phone number: " NEWPHONENUMBER
  chfn -p "$NEWPHONENUMBER" "$SELECTEDUSER"
}
function editUserFullname(){
  clear
  read -p "Enter new $SELECTEDUSER fullname: " NEWFULLNAME
  chfn -f "$NEWFULLNAME" "$SELECTEDUSER"
}
function editUserRoom(){
  clear
  read -p "Enter new $SELECTEDUSER room number: " NEWROOM
  chfn -r "$NEWROOM" "$SELECTEDUSER"
}
function editUserInformationMenu(){
  CHOICE=""
  echo "1. Edit user fullname"
  echo "2. Edit user phone number"
  echo "3. Edit user work phone number"
  echo "4. Edit user room"
  echo "5. Exit"
  read -p "Enter 1-5" CHOICE
  case "$CHOICE" in
    1) editUserFullname
    ;;
    2) editUserPhone
    ;;
    3) editUserWorkPhone
    ;;
    4) editUserRoom
    ;;
    5) EXITEDITUSERINFORMATIONMENU=1
    ;;
  esac
}

function editUserInformation(){
  while [ $EXITEDITUSERINFORMATIONMENU -eq 0 ] && [ $USEREXISTS -eq 1 ]; do
    editUserInformationMenu
  done
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
  echo "13. Make user FTP only"
  echo "14. Make user standard user"
  echo "15. Make user read-only to shared directory $SHAREDREADONLYDIRECTORY"
  echo "16. Make user read-write to shared directory $SHAREDREADWRITEDIRECTORY"
  echo "17. Remove user from shared directories"
  echo "18. Jail/free chroot"
  echo "19. Edit user information"
  echo "20. Exit"
  read -p "Enter 1-19 to chose option: " CHOICE
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
    13) makeUserFTPOnly
    ;;
    14) makeUserNotFTPOnly
    ;;
    15) makeUserReadOnlySharedDir
    ;;
    16) makeUserReadWriteSharedDir
    ;;
    17) removeUserFromSharedDirectories
    ;;
    18) jailFTP
    ;;
    19) editUserInformation
    ;;
    20) clear 
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
  getent group $SELECTEDGROUP | awk -F: '{print "Group GID: " $3}'
  CHOICE='n'
  read -p "Do you really want to change $SELECTEDGROUP GID?: [N\y]" CHOICE
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
  read -p "Do you really want to change $SELECTEDGROUP name?: [N\y]" CHOICE
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
  clear
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
  while [ $EXITEDITGROUPMENU -eq 0 ] && [ $GROUPEXISTS -eq 1 ]; do
    editGroupMenu
  done
}

#loop for editing users
function editUser(){
  while [ $EXITEDITUSERMENU -eq 0 ] && [ $USEREXISTS -eq 1 ]; do
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
  echo "11. Exit"
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

function checkConfiguration(){
  if ! getent group "$SHAREDREADWRITEGROUP" >/dev/null;then
    groupadd "$SHAREDREADWRITEGROUP"
  fi
  if ! getent group "$SHAREDREADONLYGROUP" >/dev/null;then
    groupadd "$SHAREDREADONLYGROUP"
  fi
  if ! [ -d "$SHAREDREADWRITEDIRECTORY" ];then
    mkdir "/home/$SHAREDREADWRITEDIRECTORY"
    chown "root:$SHAREDREADWRITEGROUP" "$SHAREDREADWRITEDIRECTORY"
    chmod 770 "$SHAREDREADWRITEDIRECTORY"
  fi
  if ! [ -d "$SHAREDREADONLYDIRECTORY" ];then
    mkdir "/home/$SHAREDREADONLYDIRECTORY"
    chown "root:$SHAREDREADONLYGROUP" "$SHAREDREADONLYDIRECTORY"
    chmod 750 "$SHAREDREADONLYDIRECTORY"
  fi
  if ! dnf list installed "vsftpd" > /dev/null 2>&1;then
    echo "Vsftpd not installed, script will not work correctly"
    read -p "Do you want to install it? [N\y] " CHOICE
    if [ "$CHOICE" = "y"  ] && [ "$CHOICE" = "Y" ];then
      dnf -y install vsftpd
    fi
  fi
  if dnf list installed "vsftpd" > /dev/null 2>&1;then
    if ! [ -f "$CHROOTLISTPATH" ];then
      touch "/etc/vsftpd/chroot_list"
    fi
  fi
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
checkConfiguration
#main loop of the script
while [ $EXIT -eq 0 ]; do
  menu   
done
