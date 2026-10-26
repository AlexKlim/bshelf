import * as Dialog from "@radix-ui/react-dialog"
import type { ReactNode } from "react"
import { useTranslation } from "react-i18next"
import { Ico } from "./ui"

type Props = {
  open: boolean
  label: string
  onClose: () => void
  children: ReactNode
} & Pick<Dialog.DialogContentProps, "className" | "onEscapeKeyDown" | "onCloseAutoFocus">

export function Overlay({ open, label, onClose, children, className, onEscapeKeyDown, ...content }: Props) {
  const { t } = useTranslation()
  return (
    <Dialog.Root open={open} onOpenChange={(next) => !next && onClose()}>
      <Dialog.Portal>
        <Dialog.Overlay className="bs-scrim" />
        <Dialog.Content
          {...content}
          onEscapeKeyDown={(e) => {
            if ((e.target as Element | null)?.closest?.(".bs-month[data-open]")) return e.preventDefault()
            onEscapeKeyDown?.(e)
          }}
          className={className ? `bs-dialog ${className}` : "bs-dialog"}
          aria-describedby={undefined}
          onClick={(e) => e.target === e.currentTarget && onClose()}
        >
          <Dialog.Title className="bs-sr">{label}</Dialog.Title>
          <Dialog.Close className="bs-iconbtn bs-dialog__close" aria-label={t("common.close")}>
            <Ico name="close" />
          </Dialog.Close>
          <div className="bs-dialog__body">{children}</div>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  )
}
