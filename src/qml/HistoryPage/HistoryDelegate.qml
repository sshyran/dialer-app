/*
 * Copyright 2012-2013 Canonical Ltd.
 *
 * This file is part of dialer-app.
 *
 * dialer-app is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * dialer-app is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.0
import Ubuntu.Components 1.1
import Ubuntu.Components.ListItems 0.1 as ListItem
import Ubuntu.Components.Popups 0.1
import Ubuntu.Telephony 0.1
import Ubuntu.Telephony.PhoneNumber 0.1 as PhoneUtils
import Ubuntu.Contacts 0.1
import QtContacts 5.0
import "dateUtils.js" as DateUtils

ListItemWithActions {
    id: historyDelegate

    readonly property var participant: model.participants && model.participants[0] ? model.participants[0] : {}
    readonly property bool incoming: model.senderId !== "self"
    readonly property bool unknownContact: contactId === ""
    readonly property string phoneNumber: participant.phoneNumber ? participant.phoneNumber : ""
    readonly property string contactId: participant.contactId ? participant.contactId : ""
    readonly property bool interactive: participant.phoneNumber &&
                                        participant.phoneNumber !== "" &&
                                        participant.phoneNumber !== "x-ofono-private" &&
                                        participant.phoneNumber !== "x-ofono-unknown"

    property string phoneNumberSubTypeLabel: ""
    property bool isFirst: false
    property bool fullView: false
    property bool active: false

    function activate() {
        // ignore private and unknown numbers
        if (!interactive) {
            return;
        }

        if (fullView && mainView.account) {
            mainView.call(participant.phoneNumber, mainView.account.accountId);
        } else {
            mainView.populateDialpad(participant.phoneNumber, mainView.account ? mainView.account.accountId : "");
        }
    }

    function selectCallType()  {
        if (model.callMissed) {
            return i18n.tr("Missed");
        } else if (incoming) {
            return i18n.tr("Incoming");
        } else {
            return i18n.tr("Outgoing");
        }
    }

    height: units.gu(8)
    color: Theme.palette.normal.background
    triggerActionOnMouseRelease: true

    states: [
        State {
            name: "basicView"
            when: !fullView
            PropertyChanges {
                target: time
                opacity: 0
            }
            PropertyChanges {
                target: callType
                opacity: 0
            }
        }
    ]

    transitions: [
        Transition {
            UbuntuNumberAnimation {
                properties: "opacity"
            }
        }
    ]

    Item {
        id: helper

        function updateSubTypeLabel() {
            var subLabel = "";
            if (phoneNumber !== "") {
                var typeInfo = phoneTypeModel.get(phoneTypeModel.getTypeIndex(phoneDetail))
                if (typeInfo) {
                    subLabel = typeInfo.label
                }
            }
            phoneNumberSubTypeLabel = subLabel
        }

        Component.onCompleted: updateSubTypeLabel()

        PhoneNumber {
            id: phoneDetail
            contexts: participant.phoneContexts ? participant.phoneContexts : []
            subTypes: participant.phoneSubTypes ? participant.phoneSubTypes : []
        }

        ContactDetailPhoneNumberTypeModel {
            id: phoneTypeModel
            Component.onCompleted: helper.updateSubTypeLabel()
        }
    }

    Rectangle {
        anchors {
            fill: parent
            topMargin: units.gu(-1)
            bottomMargin: units.gu(-1)
            leftMargin: units.gu(-2)
            rightMargin: units.gu(-2)
        }
        opacity: historyDelegate.active ? 0.2 : 0.0
        color: "black"
        Behavior on opacity {
            UbuntuNumberAnimation {}
        }
    }

    ContactAvatar {
        id: avatar
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }
        width: height
        fallbackAvatarUrl: (participant.avatar  && participant.avatar !== "") ? participant.avatar : "image://theme/stock_contact"
        fallbackDisplayName: (participant.alias && participant.alias !== "") ? participant.alias : phoneNumber
        showAvatarPicture: (fallbackAvatarUrl != "image://theme/stock_contact") || (initials.length === 0)
    }

    Label {
        id: titleLabel
        anchors {
            top: parent.top
            topMargin: units.gu(0.5)
            left: avatar.right
            leftMargin: units.gu(2)
            right: time.left
            rightMargin: units.gu(1) + (countLabel.visible ? countLabel.width : 0)
        }
        height: units.gu(2)
        verticalAlignment: Text.AlignTop
        fontSize: "medium"
        text: {
            if (participant.phoneNumber == "x-ofono-private") {
                return i18n.tr("Private number")
            } else if (participant.phoneNumber == "x-ofono-unknown") {
                return i18n.tr("Unknown number")
            } else if (participant.alias && participant.alias !== "") {
                return participant.alias
            }
            return PhoneUtils.PhoneUtils.format(participant.phoneNumber)
        }
        elide: Text.ElideRight
        color: UbuntuColors.lightAubergine
    }

    // this item has the width of the text above. It is used to be able to align
    Item {
        id: titleLabelArea
        anchors {
            top: titleLabel.top
            left: titleLabel.left
            bottom: titleLabel.bottom
        }
        width: titleLabel.paintedWidth
    }

    Label {
        id: countLabel
        anchors {
            left: titleLabelArea.right
            leftMargin: units.gu(0.5)
            top: titleLabel.top
        }
        height: units.gu(2)
        fontSize: "medium"
        visible: model.eventCount > 1
        // TRANSLATORS: this is the count of events grouped into this single item
        text: i18n.tr("(%1)").arg(model.eventCount)
    }

    Label {
        id: phoneLabel
        anchors {
            top: titleLabel.bottom
            topMargin: units.gu(1)
            left: avatar.right
            leftMargin: units.gu(2)
        }
        height: units.gu(2)
        verticalAlignment: Text.AlignTop
        fontSize: "small"
        // FIXME: handle conference call
        text: phoneNumberSubTypeLabel
        visible: interactive && !unknownContact
    }

    // time and duration on the right side of the delegate
    Label {
        id: time
        anchors {
            right: parent.right
            bottom: titleLabel.bottom
        }
        height: units.gu(2)
        verticalAlignment: Text.AlignBottom
        fontSize: "small"
        // TRANSLATORS: this string is the time a call has happenend. It represents the format to be used, according to:
        // http://qt-project.org/doc/qt-5/qml-qtqml-qt.html#formatDate-method
        // please change according to your language
        text: Qt.formatTime(model.timestamp, i18n.tr("hh:mm ap"))
    }

    Label {
        id: callType
        anchors {
            right: parent.right
            bottom: phoneLabel.bottom
        }
        height: units.gu(2)
        verticalAlignment: Text.AlignBottom
        fontSize: "small"
        text: selectCallType()
    }
}
