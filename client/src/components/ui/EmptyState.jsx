
export default function EmptyState({ icon: Icon, title, description, action }) {
  return (
    <div className="flex flex-col items-center justify-center py-16 text-center space-y-4">
      {Icon && (
        <div className="w-16 h-16 rounded-2xl bg-white/4 border border-white/5 flex items-center justify-center text-gray-500">
          <Icon className="w-7 h-7" />
        </div>
      )}
      <div>
        <h3 className="text-sm font-semibold text-gray-300">{title}</h3>
        {description && <p className="text-xs text-gray-500 mt-1">{description}</p>}
      </div>
      {action}
    </div>
  );
}
