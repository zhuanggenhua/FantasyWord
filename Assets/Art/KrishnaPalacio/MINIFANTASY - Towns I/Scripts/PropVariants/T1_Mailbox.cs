using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Minifantasy.TownsI
{
    public class T1_Mailbox : MonoBehaviour
    {
        [Tooltip("Select a Prop Variant.")]
        [SerializeField] private MailboxSelection selection = MailboxSelection.Mailbox1;

        [Header("Sprites")]
        [SerializeField] private Sprite mailbox1;
        [SerializeField] private Sprite mailbox2;

        [Header("Shadows")]
        [SerializeField] private Sprite shadowMailbox1;
        [SerializeField] private Sprite shadowMailbox2;

        private void OnValidate()
        {
            Sprite selectedSprite = null;
            Sprite selectedShadow = null;

            switch (selection)
            {
                case MailboxSelection.Mailbox1:
                    selectedSprite = mailbox1;
                    selectedShadow = shadowMailbox1;
                    break;
                case MailboxSelection.Mailbox2:
                    selectedSprite = mailbox2;
                    selectedShadow = shadowMailbox2;
                    break;
            }
            GetComponent<SpriteRenderer>().sprite = selectedSprite;
            transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite = selectedShadow;
        }

        private enum MailboxSelection
        {
            Mailbox1,
            Mailbox2,
        }
    }
}