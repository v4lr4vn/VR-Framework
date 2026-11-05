-- The small numbers on the app icons: unread messages, and missed calls plus new voicemail.
function Phone.badges(number)
    return {
        messages = Phone.Messages.unread(number),
        phone = Phone.Calls.unseenMissed(number) + Phone.Voicemail.unheard(number),
        mail = Phone.Mail.unreadByNumber(number),
    }
end
